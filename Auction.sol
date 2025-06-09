// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Enhanced Auction Contract
 * @dev Implements an auction system with the following features:
 * - Bids with deposit
 * - Automatic refund to losers
 * - 2% commission on completion
 * - Time extension if bids occur in the last 10 minutes
 * - Partial refund of previous bids
 * - Separation between owner (collects commission) and seller (receives payment)
 */
contract Auction {
    // Constants for gas optimization
    uint256 public constant MIN_INCREASE_PERCENTAGE = 5; // 5% minimum increase
    uint256 public constant EXTENSION_TIME = 10 minutes;
    uint256 public constant COMMISSION_PERCENTAGE = 2; // 2% commission
    
    address public owner;           // Who deploys the contract and collects commission
    address public seller;          // Who receives payment for the item
    string public itemDescription;
    uint public startTime;
    uint public endTime;
    
    address public highestBidder;
    uint public highestBid;
    
    bool public ended = false;
    bool public refundsProcessed = false; // Prevents double execution
    
    // Mapping of addresses to their total bids
    mapping(address => uint) public bids;
    // Mapping of addresses to their valid bids (for partial refund)
    mapping(address => uint[]) public validBids;
    // Array of all bidders
    address[] public bidders;
    
    // Events
    event NewBid(address indexed bidder, uint amount, uint timestamp);
    event AuctionEnded(address winner, uint amount, uint timestamp);
    event RefundIssued(address bidder, uint amount);
    event PartialRefundIssued(address bidder, uint amount);
    event PaymentProcessed(address seller, uint amount, address owner, uint commission);
    
    /**
     * @dev Constructor that initializes the auction
     * @param _itemDescription Description of the item being auctioned
     * @param _durationInMinutes Auction duration in minutes
     * @param _seller Address that will receive payment (can be the same as owner)
     */
    constructor(
        string memory _itemDescription, 
        uint _durationInMinutes,
        address _seller
    ) {
        require(_seller != address(0), "Seller address cannot be zero");
        require(_durationInMinutes > 0, "Duration must be greater than zero");
        
        owner = msg.sender;
        seller = _seller;
        itemDescription = _itemDescription;
        startTime = block.timestamp;
        endTime = startTime + (_durationInMinutes * 1 minutes);
    }
    
    /**
     * @dev Modifier to check if the auction is active
     */
    modifier onlyActive() {
        require(block.timestamp >= startTime, "Auction has not started yet");
        require(block.timestamp < endTime, "Auction has ended");
        require(!ended, "Auction has already been manually ended");
        _;
    }
    
    /**
     * @dev Modifier to check if the auction has ended
     */
    modifier onlyEnded() {
        require(block.timestamp > endTime || ended, "Auction has not ended yet");
        _;
    }
    
    /**
     * @dev Modifier to check if the sender is the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }
    
    /**
     * @dev Function to place a bid
     */
    function bid() public payable onlyActive {
        // Verify that the bid is higher than current bid + 5%
        uint minBid = highestBid + (highestBid * MIN_INCREASE_PERCENTAGE / 100);
        require(msg.value > minBid || highestBid == 0, "Bid must be at least 5% higher than current bid");
        
        // If it's the user's first bid, add them to the bidders array
        if (bids[msg.sender] == 0) {
            bidders.push(msg.sender);
        } else {
            // Only save previous bids if they already had some (CORRECTION HERE)
            validBids[msg.sender].push(bids[msg.sender]);
        }
        
        // Update the user's total bid
        bids[msg.sender] += msg.value;
        
        // Update the highest bid if applicable
        if (bids[msg.sender] > highestBid) {
            highestBid = bids[msg.sender];
            highestBidder = msg.sender;
            
            // Extend time if bid is placed in the last 10 minutes
            if (endTime - block.timestamp < EXTENSION_TIME) {
                endTime = block.timestamp + EXTENSION_TIME;
            }
        }
        
        // Emit new bid event
        emit NewBid(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Function to request partial refund of previous bids
     * NOTE: The current winner cannot request partial refund
     */
    function requestPartialRefund() public onlyActive {
        require(msg.sender != highestBidder, "Current winner cannot request partial refund");
        require(validBids[msg.sender].length > 0, "You have no previous bids to refund");
        
        uint totalToRefund = 0;
        for (uint i = 0; i < validBids[msg.sender].length; i++) {
            totalToRefund += validBids[msg.sender][i];
        }
        
        require(totalToRefund > 0, "No amount to refund");
        
        // Update the user's balance
        bids[msg.sender] -= totalToRefund;
        
        // Clear the valid bids history
        delete validBids[msg.sender];
        
        // Transfer the refund
        (bool success, ) = payable(msg.sender).call{value: totalToRefund}("");
        require(success, "Error sending partial refund");
        
        emit PartialRefundIssued(msg.sender, totalToRefund);
    }
    
    /**
     * @dev Function to end the auction
     */
    function endAuction() public onlyOwner {
        require(block.timestamp >= startTime, "Auction has not started yet");
        require(!ended, "Auction has already been ended");
        
        ended = true;
        
        // Emit auction ended event
        emit AuctionEnded(highestBidder, highestBid, block.timestamp);
        
        // Process refunds and payments automatically
        _processRefunds();
    }
    
    /**
     * @dev Internal function to process refunds to losers and payments
     */
    function _processRefunds() internal {
        require(!refundsProcessed, "Refunds have already been processed");
        refundsProcessed = true;
        
        // If there are no bids, nothing to process
        if (highestBid == 0) {
            return;
        }
        
        // Calculate commission and payment to seller
        uint commission = highestBid * COMMISSION_PERCENTAGE / 100;
        uint sellerAmount = highestBid - commission;
        
        // Refund all bidders except the winner
        for (uint i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            
            if (bidder != highestBidder && bids[bidder] > 0) {
                uint refundAmount = bids[bidder];
                bids[bidder] = 0; // Prevent reentrancy
                
                // Transfer the refund
                (bool success, ) = payable(bidder).call{value: refundAmount}("");
                require(success, "Error sending refund");
                
                emit RefundIssued(bidder, refundAmount);
            }
        }
        
        // Clear the winner's bid to avoid confusion
        if (highestBidder != address(0)) {
            bids[highestBidder] = 0;
        }
        
        // Transfer main payment to seller
        if (sellerAmount > 0) {
            (bool sellerSuccess, ) = payable(seller).call{value: sellerAmount}("");
            require(sellerSuccess, "Error sending payment to seller");
        }
        
        // Transfer commission to owner
        if (commission > 0) {
            (bool ownerSuccess, ) = payable(owner).call{value: commission}("");
            require(ownerSuccess, "Error sending commission to owner");
        }
        
        emit PaymentProcessed(seller, sellerAmount, owner, commission);
    }
    
    /**
     * @dev Emergency function to process refunds manually
     * Only available if auction has ended but refunds haven't been processed
     */
    function processRefundsManually() public onlyEnded {
        require(!refundsProcessed, "Refunds have already been processed");
        _processRefunds();
    }
    
    /**
     * @dev Function to get the auction winner
     * @return Winner's address and winning bid amount
     */
    function getWinner() public view onlyEnded returns (address, uint) {
        return (highestBidder, highestBid);
    }
    
    /**
     * @dev Function to get all current bids
     * @return Arrays with bidder addresses and their amounts
     */
    function getAllBids() public view returns (address[] memory, uint[] memory) {
        uint[] memory amounts = new uint[](bidders.length);
        
        for (uint i = 0; i < bidders.length; i++) {
            amounts[i] = bids[bidders[i]];
        }
        
        return (bidders, amounts);
    }
    
    /**
     * @dev Function to check remaining auction time
     * @return Remaining time in seconds
     */
    function getRemainingTime() public view returns (uint) {
        if (block.timestamp >= endTime || ended) {
            return 0;
        }
        return endTime - block.timestamp;
    }
    
    /**
    * @dev Function to get general auction information
    * @return description Description of the item being auctioned
    */
    function getAuctionInfo() public view returns (
        string memory description,
        uint _startTime,
        uint _endTime,
        address _highestBidder,
        uint _highestBid,
        bool _ended,
        bool _refundsProcessed,
        uint _remainingTime
    ) {
        return (
            itemDescription,
            startTime,
            endTime,
            highestBidder,
            highestBid,
            ended,
            refundsProcessed,
            getRemainingTime()
        );
    }
    
    /**
     * @dev Function to get valid bids history for a user
     * @param bidder Bidder's address
     * @return Array with previous valid bids
     */
    function getValidBids(address bidder) public view returns (uint[] memory) {
        return validBids[bidder];
    }
}