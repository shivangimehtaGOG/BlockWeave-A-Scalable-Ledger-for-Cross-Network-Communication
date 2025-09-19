// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BlockWeave
 * @dev A scalable ledger for cross-network communication
 */
contract BlockWeave {
    struct CrossChainMessage {
        uint256 messageId;
        address sender;
        string targetNetwork;
        string content;
        uint256 timestamp;
        bool isProcessed;
        uint256 fee;
    }
    
    struct NetworkBridge {
        string networkName;
        address bridgeAddress;
        bool isActive;
        uint256 totalMessages;
    }
    
    // State variables
    mapping(uint256 => CrossChainMessage) public messages;
    mapping(string => NetworkBridge) public networkBridges;
    mapping(address => uint256[]) public userMessages;
    
    uint256 public messageCounter;
    uint256 public constant BASE_FEE = 0.001 ether;
    address public owner;
    
    // Events
    event MessageSent(
        uint256 indexed messageId,
        address indexed sender,
        string targetNetwork,
        string content,
        uint256 fee
    );
    
    event MessageProcessed(uint256 indexed messageId, string targetNetwork);
    event NetworkBridgeRegistered(string networkName, address bridgeAddress);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validNetwork(string memory networkName) {
        require(networkBridges[networkName].isActive, "Network bridge not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        messageCounter = 0;
    }
    
    /**
     * @dev Send a cross-chain message
     * @param targetNetwork The target blockchain network
     * @param content The message content to send
     */
    function sendMessage(
        string memory ta
