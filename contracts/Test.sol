//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Test {
    mapping(address => uint256) public nonces;
    address public signer;
    uint256 private constant feeDecimals = 2;
    uint256 count;
    mapping(address => uint256) private userRoyalties;
    constructor(address _signer) {
        signer = _signer;
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
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature
    ) private view {
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
                    _nonce,
                    _deadline
                )
            );

        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(
            messageHash
        );

        require(
            ECDSA.recover(ethSignedMessageHash, _signature) == signer,
            "Test: Invalid Signature in buy"
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
        uint256 deadline,
        bytes memory _signature
    ) external {          

        uint256 _nonce = nonces[msg.sender];

        _verifyBuyMessage(
            _collection,
            msg.sender,
            _seller,
            _creator,
            _tokenId,
            _quantity,
            _price,
            _royaltyAmount,
            _nonce,
            deadline,
            _signature
        );   

        _nonce = _nonce + 1;
        nonces[msg.sender] = _nonce;

        uint256 tokenAmount = _price * _quantity;
        uint256 feeAmount = (tokenAmount * 150) / 10000;
        
        tokenAmount -= feeAmount;
        
        count = tokenAmount;

        uint256 _royalty = userRoyalties[msg.sender];
        _royalty += tokenAmount;
        userRoyalties[msg.sender] = _royalty;
    }
}