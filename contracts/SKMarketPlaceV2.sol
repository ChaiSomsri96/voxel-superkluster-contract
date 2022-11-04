//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

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

contract SKMarketPlaceV2 is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {

    IERC20 private vxlToken; // Voxel Token Address

    uint256 private constant feeDecimals = 2;
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

    uint256 public counter;

    event TransferBundle(
        address from,
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

    function setCounter(uint256 _counter) external onlyTimeLockController {
        counter = _counter;
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
}
