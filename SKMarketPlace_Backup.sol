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
    uint256[] quantities;
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

    IERC20 private vxlToken; // Voxel Token Address
    
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

    event AddItem(
        address collection,
        address from,
        uint256 tokenId,
        uint256 quantity,
        string tokenURI,
        uint256 timestamp
    );
    event BuyItem(
        address collection,
        address buyer,
        address seller,
        uint256 tokenId,
        uint256 quantity,
        uint256 price,
        uint256 timestamp
    );
    event AcceptItem(
        address collection,
        address seller,
        address buyer,
        uint256 tokenId,
        uint256 quantity,
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
        address _signer, 
        address _skTeamWallet, 
        address _timeLockController
    ) public initializer {
        vxlToken = IERC20(_vxlToken);
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
            "SKMarketPlace: Invalid seller address"
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

            emit AddItem(_collection, _msgSender(), _tokenId, _mintQty, _tokenURI, block.timestamp);
        }

        _buyProcess(_collection, _msgSender(), _buyer, _creator, _tokenId, _quantity, _price, _royaltyAmount);

        emit AcceptItem(
            _collection,
            _msgSender(),
            _buyer,
            _tokenId,
            _quantity,
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

            emit AddItem(_collection, _seller, _tokenId, _mintQty, _tokenURI, block.timestamp);
        }

        _buyProcess(_collection, _seller, _msgSender(), _creator, _tokenId, _quantity, _price, _royaltyAmount);
        
        emit BuyItem(_collection, _msgSender(), _seller, _tokenId, _quantity, _price, block.timestamp);
    }

    function bundleTransfer(
        Receiver[] memory _receivers
    ) external whenNotPaused nonReentrant {
        require(
            _receivers.length > 0,
            "SKMarketPlace: Invalid receiver list"
        );

        for(uint256 i = 0; i < _receivers.length; i = unsafe_inc(i)) {
            require(
                _receivers[i].receiver != address(0x0) && _receivers[i].collections.length > 0,
                "SKMarketPlace: Invalid receiver address or collection list"
            );
            for(uint256 j = 0; j < _receivers[i].collections.length; j = unsafe_inc(j)) {
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
                    for(uint256 k = 0; k < _receivers[i].collections[j].tokenIds.length; k = unsafe_inc(k)) {
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

        uint256 _nonce = nonces[_msgSender()];

        bytes memory data = _verifyCartMessage(_sellers);

        bytes32 messageHash = keccak256(abi.encodePacked(data, _msgSender(), _cartPrice, _payload, _nonce, deadline));
        require(
            ECDSA.recover(ECDSA.toEthSignedMessageHash(messageHash), _signature) == signer,
            "SKMarketPlace: Invalid Signature in buyCart"
        );

        _nonce = _nonce + 1;
        nonces[_msgSender()] = _nonce;

        vxlToken.transferFrom(_msgSender(), address(this), _cartPrice);

        uint256 totalFeeAmount;

        for(uint i = 0; i < _sellers.length; i = unsafe_inc(i)) {
            uint256 tokenAmount = _sellers[i].price;
            uint256 feeAmount;

            if (serviceFee > 0) {
                feeAmount = (tokenAmount * serviceFee) / 10000;
                tokenAmount = tokenAmount - feeAmount;
                totalFeeAmount = totalFeeAmount + feeAmount;
            }

            CartSeller memory sellerInfo = _sellers[i];

            for(uint j = 0; j < sellerInfo.collections.length; j = unsafe_inc(j)) {
                if(IERC165(sellerInfo.collections[j].collection).supportsInterface(InterfaceId_ERC2981)) {
                    address[] memory receivers = new address[](sellerInfo.collections[j].tokenIds.length);
                    uint256[] memory royaltyAmounts = new uint256[](sellerInfo.collections[j].tokenIds.length);
                    address collectionElm = sellerInfo.collections[j].collection;
                    for(uint k = 0; k < sellerInfo.collections[j].tokenIds.length; k = unsafe_inc(k)) {
                        (address _receiver, uint256 royaltyAmount) = IERC2981(
                            collectionElm
                        ).royaltyInfo(sellerInfo.collections[j].tokenIds[k], sellerInfo.collections[j].prices[k]);
                        royaltyAmount = royaltyAmount * sellerInfo.collections[j].quantities[k];
                        
                        receivers[k] = _receiver;
                        royaltyAmounts[k] = royaltyAmount;
                    }
                    tokenAmount = _multiRoyaltyProcess(receivers, royaltyAmounts, tokenAmount);
                }
                else {
                    tokenAmount = _multiRoyaltyProcess(sellerInfo.collections[j].creators, sellerInfo.collections[j].royaltyAmounts, tokenAmount);
                }

                for(uint k = 0; k < sellerInfo.collections[j].tokenIds.length; k = unsafe_inc(k)) {
                    if(bytes(sellerInfo.collections[j].tokenURIs[k]).length > 0) {
                        ISKCollection(sellerInfo.collections[j].collection).mintItem(
                            sellerInfo.seller,
                            sellerInfo.collections[j].tokenIds[k],
                            1,
                            sellerInfo.collections[j].tokenURIs[k]
                        );                        

                        emit AddItem(sellerInfo.collections[j].collection, sellerInfo.seller, sellerInfo.collections[j].tokenIds[k], 1, sellerInfo.collections[j].tokenURIs[k], block.timestamp);
                    }
                }

                if(sellerInfo.collections[j].batch) {
                    IERC1155(sellerInfo.collections[j].collection).safeBatchTransferFrom(
                        sellerInfo.seller,
                        _msgSender(),
                        sellerInfo.collections[j].tokenIds,
                        sellerInfo.collections[j].quantities,
                        ""
                    );
                }
                else {
                    for(uint k = 0; k < sellerInfo.collections[j].tokenIds.length; k = unsafe_inc(k)) {
                        IERC721(sellerInfo.collections[j].collection).safeTransferFrom(
                            sellerInfo.seller,
                            _msgSender(),
                            sellerInfo.collections[j].tokenIds[k]
                        );
                    }
                }   
            }
            vxlToken.transfer(sellerInfo.seller, tokenAmount);
        }

        if (totalFeeAmount > 0) {
            vxlToken.transfer(skTeamWallet, totalFeeAmount);
        }

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

        vxlToken.transferFrom(sender, address(this), royaltyAmount);
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

        for(uint256 i = 0; i < receivers.length; i ++) {
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

        vxlToken.transferFrom(_buyer, _seller, tokenAmount);
        if(feeAmount > 0) {
            vxlToken.transferFrom(_buyer, skTeamWallet, feeAmount);
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

    function _verifyCartMessage(
        CartSeller[] calldata _sellers
    ) private pure returns (bytes memory) {
        bytes memory data;

        for(uint i = 0; i < _sellers.length; i = unsafe_inc(i)) {
            for(uint j = 0; j < _sellers[i].collections.length; j = unsafe_inc(j)) {
                for(uint k = 0; k < _sellers[i].collections[j].tokenIds.length; k = unsafe_inc(k)) {
                    data = abi.encodePacked(data,
                        _sellers[i].collections[j].creators[k],
                        _sellers[i].collections[j].tokenIds[k],
                        _sellers[i].collections[j].quantities[k],
                        _sellers[i].collections[j].prices[k],
                        _sellers[i].collections[j].royaltyAmounts[k],
                        _sellers[i].collections[j].tokenURIs[k]
                    );
                }
                data = abi.encodePacked(data, _sellers[i].collections[j].collection, _sellers[i].collections[j].batch);
            }
            data = abi.encodePacked(data, _sellers[i].seller, _sellers[i].price);            
        }

        return data;
    }
}
