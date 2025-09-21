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
    event MessageUpdated(uint256 indexed messageId, string newContent);
    event MessageCancelled(uint256 indexed messageId, address indexed sender, uint256 refundAmount);
    
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
        string memory targetNetwork,
        string memory content
    ) external payable validNetwork(targetNetwork) {
        require(msg.value >= BASE_FEE, "Insufficient fee");
        require(bytes(content).length > 0, "Message content cannot be empty");
        require(bytes(targetNetwork).length > 0, "Target network cannot be empty");
        
        messageCounter++;
        
        messages[messageCounter] = CrossChainMessage({
            messageId: messageCounter,
            sender: msg.sender,
            targetNetwork: targetNetwork,
            content: content,
            timestamp: block.timestamp,
            isProcessed: false,
            fee: msg.value
        });
        
        userMessages[msg.sender].push(messageCounter);
        networkBridges[targetNetwork].totalMessages++;
        
        emit MessageSent(messageCounter, msg.sender, targetNetwork, content, msg.value);
    }
    
    /**
     * @dev Register a new network bridge
     * @param networkName The name of the network
     * @param bridgeAddress The address of the bridge contract
     */
    function registerNetworkBridge(
        string memory networkName,
        address bridgeAddress
    ) external onlyOwner {
        require(bytes(networkName).length > 0, "Network name cannot be empty");
        require(bridgeAddress != address(0), "Invalid bridge address");
        
        networkBridges[networkName] = NetworkBridge({
            networkName: networkName,
            bridgeAddress: bridgeAddress,
            isActive: true,
            totalMessages: 0
        });
        
        emit NetworkBridgeRegistered(networkName, bridgeAddress);
    }
    
    /**
     * @dev Process a cross-chain message (mark as completed)
     * @param messageId The ID of the message to process
     */
    function processMessage(uint256 messageId) external onlyOwner {
        require(messageId > 0 && messageId <= messageCounter, "Invalid message ID");
        require(!messages[messageId].isProcessed, "Message already processed");
        
        messages[messageId].isProcessed = true;
        
        emit MessageProcessed(messageId, messages[messageId].targetNetwork);
    }

    // -------------------- New Useful Functions --------------------
    
    /**
     * @dev Update message content before it's processed
     * @param messageId The ID of the message
     * @param newContent The new content for the message
     */
    function updateMessageContent(uint256 messageId, string memory newContent) external {
        CrossChainMessage storage msgData = messages[messageId];
        require(msg.sender == msgData.sender, "Only sender can update");
        require(!msgData.isProcessed, "Message already processed");
        require(bytes(newContent).length > 0, "Content cannot be empty");

        msgData.content = newContent;
        emit MessageUpdated(messageId, newContent);
    }

    /**
     * @dev Cancel a message and refund fee if not processed
     * @param messageId The ID of the message
     */
    function cancelMessage(uint256 messageId) external {
        CrossChainMessage storage msgData = messages[messageId];
        require(msg.sender == msgData.sender, "Only sender can cancel");
        require(!msgData.isProcessed, "Message already processed");
        uint256 refundAmount = msgData.fee;
        
        msgData.isProcessed = true; // mark as "finalized" to prevent re-entry
        payable(msg.sender).transfer(refundAmount);

        emit MessageCancelled(messageId, msg.sender, refundAmount);
    }

    /**
     * @dev Get all unprocessed message IDs
     */
    function getUnprocessedMessages() external view returns (uint256[] memory unprocessed) {
        uint256 count = 0;
        for (uint256 i = 1; i <= messageCounter; i++) {
            if (!messages[i].isProcessed) {
                count++;
            }
        }

        unprocessed = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= messageCounter; i++) {
            if (!messages[i].isProcessed) {
                unprocessed[index] = i;
                index++;
            }
        }
    }
    
    // -------------------- View Functions --------------------
    
    function getMessage(uint256 messageId) external view returns (CrossChainMessage memory) {
        require(messageId > 0 && messageId <= messageCounter, "Invalid message ID");
        return messages[messageId];
    }
    
    function getUserMessages(address user) external view returns (uint256[] memory) {
        return userMessages[user];
    }
    
    function getNetworkStats(string memory networkName) external view returns (NetworkBridge memory) {
        return networkBridges[networkName];
    }
    
    function getTotalMessages() external view returns (uint256) {
        return messageCounter;
    }

    /**
     * @dev Get all messages of a user filtered by target network
     */
    function getUserMessagesByNetwork(
        address user,
        string memory targetNetwork
    ) external view returns (CrossChainMessage[] memory filteredMessages) {
        uint256[] memory allMessages = userMessages[user];
        uint256 count = 0;

        for (uint256 i = 0; i < allMessages.length; i++) {
            if (
                keccak256(bytes(messages[allMessages[i]].targetNetwork)) ==
                keccak256(bytes(targetNetwork))
            ) {
                count++;
            }
        }

        filteredMessages = new CrossChainMessage[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < allMessages.length; i++) {
            if (
                keccak256(bytes(messages[allMessages[i]].targetNetwork)) ==
                keccak256(bytes(targetNetwork))
            ) {
                filteredMessages[index] = messages[allMessages[i]];
                index++;
            }
        }
    }
    
    // -------------------- Emergency Functions --------------------
    
    function withdrawFees() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    function toggleNetworkBridge(string memory networkName, bool status) external onlyOwner {
        networkBridges[networkName].isActive = status;
    }
}
