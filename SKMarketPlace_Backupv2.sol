//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "hardhat/console.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    
    function totalFee() external view returns (uint);
    function alpha() external view returns (uint);
    function beta() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address, uint, uint, uint) external;
}

interface ISKCollection {
    function mintItem(
        address account,
        uint256 tokenId,
        uint256 supply,
        string memory tokenURI_
    ) external;

    function setMarketplaceAddress (
        address _marketplaceAddress
    ) external;

    function setTokenURI(uint256 tokenId, string memory tokenURI_) external;      
}

struct CollectionInfo {
    address collection;
    bool batch;
    uint256[] tokenIds;
    uint256[] quantities;
}
struct Receiver {
    address receiver;
    CollectionInfo[] collections;
}

struct CartCollection {
    address collection;
    bool batch;
    address[] creators;
    uint256[] tokenIds;
    uint256[] prices;
    uint256[] royaltyAmounts;
    string[] tokenURIs;
}
struct CartSeller {
    address seller;
    uint256 price;
    CartCollection[] collections;
}

contract SKMarketPlace is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    
    address private vxlToken;
    address private wETH;
    address private vxlETHPair;
    
    uint256 public value;
    uint256 public serviceFee;
    address private skTeamWallet;

    address public signer;
    address private timeLockController;

    mapping(address => bool) public skCollection;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) private userRoyalties;

    bytes4 private constant InterfaceId_ERC721 = 0x80ac58cd;
    bytes4 private constant InterfaceId_ERC1155 = 0xd9b67a26;
    bytes4 private constant InterfaceId_ERC2981 = 0x2a55205a;
    bytes4 private constant InterfaceId_Reveal = 0xa811a37b;

    event BuyItem(
        address collection,
        address buyer,
        address seller,
        uint256 tokenId,
        uint256 quantity,
        uint256 mintQty,
        uint256 price,
        uint256 timestamp
    );
    event AcceptItem(
        address collection,
        address seller,
        address buyer,
        uint256 tokenId,
        uint256 quantity,
        uint256 mintQty,
        uint256 price,
        uint256 timestamp
    );
    event TransferBundle(
        address from,
        uint256 timestamp
    );
    event BuyCart(
        address buyer,
        uint256 payload,
        uint256 timestamp
    );

    function initialize(
        address _vxlToken,
        address _wETH,
        address _vxlETHPair,
        address _signer, 
        address _skTeamWallet, 
        address _timeLockController
    ) public initializer {
        vxlToken = _vxlToken;
        wETH = _wETH;
        vxlETHPair = _vxlETHPair;
        timeLockController = _timeLockController;
        skTeamWallet = _skTeamWallet;
        signer = _signer;
        serviceFee = 150;
    }

    modifier collectionCheck(address _collection) {
        require(
            IERC721(_collection).supportsInterface(InterfaceId_ERC721) ||
                IERC1155(_collection).supportsInterface(InterfaceId_ERC1155),
            "SKMarketPlace: This is not ERC721/ERC1155 collection"
        );
        _;
    }

    modifier onlyTimeLockController() {
        require(
            timeLockController == msg.sender,
            "only timeLock contract can access SKMarketPlace Contract"
        );
        _;                
    }

    function getClaimRoyalty() external view returns (uint256) {
        return userRoyalties[msg.sender];
    }

    function buyItemWithETH(
        address _collection,
        address _seller,
        address _creator,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _royaltyAmount,
        uint256 _mintQty,
        string memory _tokenURI,
        bool _shouldMint,
        uint256 deadline,
        bytes memory _signature
    ) external payable whenNotPaused nonReentrant collectionCheck(_collection) {
        require(
            _seller != address(0x0),
            "SKMarketPlace: Invalid seller address"
        );

        require(
            block.timestamp <= deadline,
            "SKMarketPlace: Invalid expiration in buyItem"
        );

        _verifyBuyMessage(
            _collection,
            _msgSender(),
            _seller, 
            _creator,
            _tokenId,
            _quantity,
            _price,
            _royaltyAmount,
            _mintQty,
            _tokenURI,
            _shouldMint,
            deadline,
            _signature
        );

        uint amountIn = msg.value;
        require(amountIn > 0, 'SKMarketPlace: INSUFFICIENT_ETH_AMOUNT');

        _swapETHForVXLTokens(amountIn, _price * _quantity, _msgSender());

        if(_shouldMint) {
            ISKCollection(_collection).mintItem(
                _seller,
                _tokenId,
                _mintQty,
                _tokenURI
            );
        }

        _buyProcess(_collection, _seller, _msgSender(), _creator, _tokenId, _quantity, _price, _royaltyAmount);

        emit BuyItem(_collection, _msgSender(), _seller, _tokenId, _quantity, _mintQty, _price, block.timestamp);
    }

    function acceptItem(
        address _collection,
        address _buyer,
        address _creator,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _royaltyAmount,
        uint256 _mintQty,
        string memory _tokenURI,
        bool _shouldMint,
        uint256 deadline,
        bytes memory _signature        
    ) external whenNotPaused nonReentrant collectionCheck(_collection) {
        require(
            _buyer != address(0x0),
            "SKMarketPlace: Invalid buyer address"
        );

        require(
            block.timestamp <= deadline,
            "SKMarketPlace: Invalid expiration in acceptItem"
        );

        _verifyBuyMessage(
            _collection,
            _buyer,
            _msgSender(),
            _creator,
            _tokenId,
            _quantity,
            _price,
            _royaltyAmount,
            _mintQty,
            _tokenURI,
            _shouldMint,
            deadline,
            _signature
        );

        if(_shouldMint) {
            ISKCollection(_collection).mintItem(
                _msgSender(),
                _tokenId,
                _mintQty,
                _tokenURI
            );
        }

        _buyProcess(_collection, _msgSender(), _buyer, _creator, _tokenId, _quantity, _price, _royaltyAmount);

        emit AcceptItem(
            _collection,
            _msgSender(),
            _buyer,
            _tokenId,
            _quantity,
            _mintQty,
            _price,
            block.timestamp
        );
    }

    function buyItem(
        address _collection,
        address _seller,
        address _creator,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _royaltyAmount,
        uint256 _mintQty,
        string memory _tokenURI,
        bool _shouldMint,
        uint256 deadline,
        bytes memory _signature
    ) external whenNotPaused nonReentrant collectionCheck(_collection) {

        require(
            _seller != address(0x0),
            "SKMarketPlace: Invalid seller address"
        );

        require(
            block.timestamp <= deadline,
            "SKMarketPlace: Invalid expiration in buyItem"
        );

        _verifyBuyMessage(
            _collection,
            _msgSender(),
            _seller, 
            _creator,
            _tokenId,
            _quantity,
            _price,
            _royaltyAmount,
            _mintQty,
            _tokenURI,
            _shouldMint,
            deadline,
            _signature
        );

        if(_shouldMint) {
            ISKCollection(_collection).mintItem(
                _seller,
                _tokenId,
                _mintQty,
                _tokenURI
            );
        }

        _buyProcess(_collection, _seller, _msgSender(), _creator, _tokenId, _quantity, _price, _royaltyAmount);
        
        emit BuyItem(_collection, _msgSender(), _seller, _tokenId, _quantity, _mintQty, _price, block.timestamp);
    }

    function bundleTransfer(
        Receiver[] memory _receivers
    ) external whenNotPaused nonReentrant {
        require(
            _receivers.length > 0,
            "SKMarketPlace: Invalid receiver list"
        );

        for(uint256 i; i < _receivers.length; i = unsafe_inc(i)) {
            require(
                _receivers[i].receiver != address(0x0) && _receivers[i].collections.length > 0,
                "SKMarketPlace: Invalid receiver address or collection list"
            );
            for(uint256 j; j < _receivers[i].collections.length; j = unsafe_inc(j)) {
                require(
                    _receivers[i].collections[j].collection != address(0x0),
                    "SKMarketPlace: Invalid receiver's collection address"
                );
                if(_receivers[i].collections[j].batch) {
                    IERC1155(_receivers[i].collections[j].collection).safeBatchTransferFrom(
                        msg.sender,
                        _receivers[i].receiver,
                        _receivers[i].collections[j].tokenIds,
                        _receivers[i].collections[j].quantities,
                        ""
                    );               
                }
                else {
                    for(uint256 k; k < _receivers[i].collections[j].tokenIds.length; k = unsafe_inc(k)) {
                        IERC721( _receivers[i].collections[j].collection).safeTransferFrom(
                            msg.sender,
                            _receivers[i].receiver,
                            _receivers[i].collections[j].tokenIds[k]
                        );      
                    }
                }
            }            
        }

        emit TransferBundle(msg.sender, block.timestamp);          
    }

    function buyCartWithETH(
        CartSeller[] calldata _sellers,
        uint256 _cartPrice,
        uint256 _payload,
        uint256 deadline,
        bytes memory _signature
    ) external payable whenNotPaused nonReentrant {
        require(
            _sellers.length > 0,
            "SKMarketPlace: Invalid seller list"
        );

        require(
            block.timestamp <= deadline,
            "SKMarketPlace: Invalid expiration in buyCart"
        );

        _verifyCartMessage(_sellers, _cartPrice, _payload, deadline, _signature);

        uint amountIn = msg.value;
        require(amountIn > 0, 'SKMarketPlace: INSUFFICIENT_ETH_AMOUNT');
        _swapETHForVXLTokens(amountIn, _cartPrice, _msgSender());

        _buyCartProcess(_sellers, _cartPrice);

        emit BuyCart(_msgSender(), _payload, block.timestamp);   
    }    

    function buyCart(
        CartSeller[] calldata _sellers,
        uint256 _cartPrice,
        uint256 _payload,
        uint256 deadline,
        bytes memory _signature
    ) external whenNotPaused nonReentrant {
        require(
            _sellers.length > 0,
            "SKMarketPlace: Invalid seller list"
        );

        require(
            block.timestamp <= deadline,
            "SKMarketPlace: Invalid expiration in buyCart"
        );

        _verifyCartMessage(_sellers, _cartPrice, _payload, deadline, _signature);
        _buyCartProcess(_sellers, _cartPrice);

        emit BuyCart(_msgSender(), _payload, block.timestamp);   
    }

    function setTimeLockController(address _timeLockController)
        external
        onlyTimeLockController
    {
        require(
            _timeLockController != address(0x0),
            "SKMarketPlace: Invalid TimeLockController"
        );
        timeLockController = _timeLockController;
    }

    function setSigner(address _signer) external onlyTimeLockController {
        require(_signer != address(0x0), "SKMarketPlace: Invalid signer");
        signer = _signer;
    }

    function setServiceFee(uint256 _serviceFee)
        external
        onlyTimeLockController
    {
        require(
            _serviceFee < 10000,
            "SKMarketPlace: ServiceFee should not reach 100 percent"
        );
        serviceFee = _serviceFee;
    }

    function setSKTeamWallet(address _skTeamWallet)
        external
        onlyTimeLockController
    {
        require(
            _skTeamWallet != address(0x0),
            "SKMarketPlace: Invalid admin team wallet address"
        );
        skTeamWallet = _skTeamWallet;
    }

    function setMarketAddressforNFTCollection(address _collection, address _newMarketplaceAddress)
        external
        whenNotPaused
        collectionCheck(_collection) 
        onlyTimeLockController
    {
        ISKCollection(_collection).setMarketplaceAddress(_newMarketplaceAddress);
    }

    function pause() external onlyTimeLockController {
        _pause();
    }

    function unpause() external onlyTimeLockController {
        _unpause();
    }

    function unsafe_inc(uint x) private pure returns (uint) {
        unchecked { return x + 1; }
    }

    function _royaltyProcess(
        address sender,
        address receiver,
        uint256 royaltyAmount,
        uint256 tokenAmount
    ) private returns (uint256) {
        require(
            royaltyAmount < tokenAmount,
            "SKMarketPlace: RoyaltyAmount exceeds than tokenAmount"
        );

        IERC20(vxlToken).transferFrom(sender, address(this), royaltyAmount);
        userRoyalties[receiver] += royaltyAmount;
        unchecked {
            tokenAmount = tokenAmount - royaltyAmount;
        }
        return tokenAmount;
    }

    function _multiRoyaltyProcess(
        address[] memory receivers,
        uint256[] memory royaltyAmounts,
        uint256 tokenAmount
    ) private returns (uint256) {

        uint256 totalRoyaltyAmount = 0;

        for(uint256 i; i < receivers.length; i ++) {
            if(receivers[i] != address(0x0) && royaltyAmounts[i] > 0) {
                userRoyalties[receivers[i]] += royaltyAmounts[i];
                totalRoyaltyAmount += royaltyAmounts[i];
            }
        }
        if(totalRoyaltyAmount > 0) {
            require(
                totalRoyaltyAmount < tokenAmount,
                "SKMarketPlace: RoyaltyAmount exceeds than tokenAmount"
            );

            unchecked {
                tokenAmount = tokenAmount - totalRoyaltyAmount;
            }
        }
        return tokenAmount;
    }

    function _buyProcess(
        address _collection,
        address _seller,
        address _buyer,
        address _creator,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _royaltyAmount
    ) private {
        uint256 tokenAmount = _price * _quantity;
        uint256 feeAmount = 0;

        if(serviceFee > 0) {
            feeAmount = (tokenAmount * serviceFee) / 10000;
            tokenAmount -= feeAmount;
        }

        if(IERC165(_collection).supportsInterface(InterfaceId_ERC2981)) {
            (address _receiver, uint256 royaltyAmount) = IERC2981(
                _collection
            ).royaltyInfo(_tokenId, _price);
            royaltyAmount = royaltyAmount * _quantity;

            if(royaltyAmount > 0) {
                tokenAmount = _royaltyProcess(_buyer, _receiver, royaltyAmount, tokenAmount);
            }
        }
        else if(_royaltyAmount > 0) {
            tokenAmount = _royaltyProcess(_buyer, _creator, _royaltyAmount, tokenAmount);
        }

        IERC20(vxlToken).transferFrom(_buyer, _seller, tokenAmount);
        if(feeAmount > 0) {
            IERC20(vxlToken).transferFrom(_buyer, skTeamWallet, feeAmount);
        }

        //ERC721
        if (IERC721(_collection).supportsInterface(InterfaceId_ERC721)) {
            IERC721(_collection).safeTransferFrom(
                _seller,
                _buyer,
                _tokenId
            );
        } else {
            IERC1155(_collection).safeTransferFrom(
                _seller,    
                _buyer,
                _tokenId,
                _quantity,
                ""
            );
        }   
    }

    function _verifyBuyMessage(
        address _collection,
        address _buyer,
        address _seller,
        address _creator,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _royaltyAmount,
        uint256 _mintQty,
        string memory _tokenURI,
        bool _shouldMint,
        uint256 _deadline,
        bytes memory _signature
    ) private {

        uint256 _nonce = nonces[_msgSender()];

        bytes32 messageHash = keccak256(
                abi.encodePacked(
                    _collection,
                    _buyer,
                    _seller,
                    _creator,
                    _tokenId,
                    _quantity,
                    _price,
                    _royaltyAmount,
                    _mintQty,
                    _tokenURI,
                    _shouldMint,
                    _nonce,
                    _deadline
                )
            );

        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(
            messageHash
        );

        require(
            ECDSA.recover(ethSignedMessageHash, _signature) == signer,
            "SKMarketPlace: Invalid Signature in buy"
        );

        _nonce = _nonce + 1;
        nonces[_msgSender()] = _nonce;
    }

    function _swapETHForVXLTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) private {
        IWETH(wETH).deposit{value: amountIn}();
        assert(IWETH(wETH).transfer(vxlETHPair, amountIn));
        uint balanceBefore = IERC20(vxlToken).balanceOf(to);

        IUniswapV2Pair pair = IUniswapV2Pair(vxlETHPair);
        (uint reserveOutput, uint reserveInput,) = pair.getReserves();

        require(reserveInput > 0 && reserveOutput > 0, "SKMarketPlace: INSUFFICIENT_LIQUIDITY");

        uint amountInput;
        amountInput = IERC20(wETH).balanceOf(vxlETHPair) - reserveInput;

        uint amountInWithFee = amountInput * 997;
        uint numerator = amountInWithFee * reserveOutput;
        uint denominator = reserveInput * 1000 + amountInWithFee;
        uint amountOut = numerator / denominator;
        
        pair.swap(amountOut, uint(0), to, new bytes(0));

        require(IERC20(vxlToken).balanceOf(to) - balanceBefore >= amountOutMin, 
        "SKMarketPlace: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function _verifyCartMessage(
        CartSeller[] calldata _sellers,
        uint256 _cartPrice,
        uint256 _payload,
        uint256 deadline,
        bytes memory _signature
    ) private {

        uint256 _nonce = nonces[_msgSender()];

        bytes memory data;

        for(uint i; i < _sellers.length; i = unsafe_inc(i)) {
            for(uint j; j < _sellers[i].collections.length; j = unsafe_inc(j)) {
                for(uint k; k < _sellers[i].collections[j].tokenIds.length; k = unsafe_inc(k)) {
                    data = abi.encodePacked(data,
                        _sellers[i].collections[j].creators[k],
                        _sellers[i].collections[j].tokenIds[k],
                        _sellers[i].collections[j].prices[k],
                        _sellers[i].collections[j].royaltyAmounts[k],
                        _sellers[i].collections[j].tokenURIs[k]
                    );
                }
                data = abi.encodePacked(data, _sellers[i].collections[j].collection, _sellers[i].collections[j].batch);
            }
            data = abi.encodePacked(data, _sellers[i].seller, _sellers[i].price);            
        }

        bytes32 messageHash = keccak256(abi.encodePacked(data, _msgSender(), _cartPrice, _payload, _nonce, deadline));

        require(
            ECDSA.recover(ECDSA.toEthSignedMessageHash(messageHash), _signature) == signer,
            "SKMarketPlace: Invalid Signature in buyCart"
        );

        _nonce = _nonce + 1;
        nonces[_msgSender()] = _nonce;
    }

    function _buyCartProcess(
        CartSeller[] calldata _sellers,
        uint256 _cartPrice
    ) private {
        IERC20(vxlToken).transferFrom(_msgSender(), address(this), _cartPrice);
        uint256 totalFeeAmount;

        for(uint i; i < _sellers.length; i = unsafe_inc(i)) {
            uint256 tokenAmount = _sellers[i].price;
            uint256 feeAmount;

            if (serviceFee > 0) {
                feeAmount = (tokenAmount * serviceFee) / 10000;
                tokenAmount = tokenAmount - feeAmount;
                totalFeeAmount = totalFeeAmount + feeAmount;
            }

            CartSeller memory sellerInfo = _sellers[i];

            for(uint j; j < sellerInfo.collections.length; j = unsafe_inc(j)) {
                if(IERC165(sellerInfo.collections[j].collection).supportsInterface(InterfaceId_ERC2981)) {
                    address[] memory receivers = new address[](sellerInfo.collections[j].tokenIds.length);
                    uint256[] memory royaltyAmounts = new uint256[](sellerInfo.collections[j].tokenIds.length);
                    address collectionElm = sellerInfo.collections[j].collection;
                    for(uint k; k < sellerInfo.collections[j].tokenIds.length; k = unsafe_inc(k)) {
                        (address _receiver, uint256 royaltyAmount) = IERC2981(
                            collectionElm
                        ).royaltyInfo(sellerInfo.collections[j].tokenIds[k], sellerInfo.collections[j].prices[k]);
                        
                        receivers[k] = _receiver;
                        royaltyAmounts[k] = royaltyAmount;
                    }
                    tokenAmount = _multiRoyaltyProcess(receivers, royaltyAmounts, tokenAmount);
                }
                else {
                    tokenAmount = _multiRoyaltyProcess(sellerInfo.collections[j].creators, sellerInfo.collections[j].royaltyAmounts, tokenAmount);
                }

                for(uint k; k < sellerInfo.collections[j].tokenIds.length; k = unsafe_inc(k)) {
                    if(bytes(sellerInfo.collections[j].tokenURIs[k]).length > 0) {
                        ISKCollection(sellerInfo.collections[j].collection).mintItem(
                            sellerInfo.seller,
                            sellerInfo.collections[j].tokenIds[k],
                            1,
                            sellerInfo.collections[j].tokenURIs[k]
                        );
                    }
                }

                if(sellerInfo.collections[j].batch) {
                    uint256[] memory quantities = new uint256[](sellerInfo.collections[j].tokenIds.length);
                    
                    for(uint k; k < quantities.length; k = unsafe_inc(k)) {
                        quantities[k] = 1;
                    }

                    IERC1155(sellerInfo.collections[j].collection).safeBatchTransferFrom(
                        sellerInfo.seller,
                        _msgSender(),
                        sellerInfo.collections[j].tokenIds,
                        quantities,
                        ""
                    );
                }
                else {
                    for(uint k; k < sellerInfo.collections[j].tokenIds.length; k = unsafe_inc(k)) {
                        IERC721(sellerInfo.collections[j].collection).safeTransferFrom(
                            sellerInfo.seller,
                            _msgSender(),
                            sellerInfo.collections[j].tokenIds[k]
                        );
                    }
                }   
            }
            IERC20(vxlToken).transfer(sellerInfo.seller, tokenAmount);
        }

        if (totalFeeAmount > 0) {
            IERC20(vxlToken).transfer(skTeamWallet, totalFeeAmount);
        }   
    }
}
