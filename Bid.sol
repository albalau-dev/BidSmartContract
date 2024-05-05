// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;


/*Smart contract for an advanced auction
  This contract allows conducting auctions of fictitious items or NFTs, with basic and advanced functionalities.
 */
contract AdvancedAuction {
    address payable public owner;
    uint256 public startDate;
    uint256 public duration;
    uint256 public initialPrice;
    uint256 public highestBid;
    address public winningBidder;
    bool public auctionEnded;
    
    mapping(address => uint256) public bids;
    mapping(address => uint256) public deposits;

    event NewBid(address bidder, uint256 bid, bool secret);
    event AuctionEnded(address winner, uint256 bid);
    
    /**
     Modifier that restricts access to only the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    
    /**
     Modifier that ensures the auction has not yet ended.
     */
    modifier auctionNotEnded() {
        require(!auctionEnded, "The auction has already ended");
        _;
    }
    
    /**
     Modifier that allows a function to be called only after a certain time.
     */
    modifier onlyAfter(uint256 _time) {
        require(block.timestamp >= _time, "Function called before the deadline");
        _;
    }
    
    /**
     Auction constructor. Assigns the contract creator as the initial owner.
     */
    constructor() {
        owner = payable(msg.sender);
    }
    
    /**
     Starts a new auction with the specified parameters.
     initialPrice The initial price of the item.
     startDate The start date of the auction.
     duration The duration of the auction in seconds.
     */
    function startAuction(uint256 _initialPrice, uint256 _startDate, uint256 _duration) public onlyOwner {
        require(_startDate > block.timestamp, "Start date must be in the future");
        require(_duration > 0, "Duration must be greater than zero");
        
        initialPrice = _initialPrice;
        startDate = _startDate;
        duration = _duration;
        auctionEnded = false;
    }
    
    /**
     Allows participants to place a bid for the item.
     secret Indicates whether the bid is secret or not.
     amount The bid amount, if not secret.
     */
    function placeBid(bool _secret, uint256 _amount) public payable auctionNotEnded {
        require(msg.value > 0 || _amount > 0, "Bid must be greater than zero");
        require(block.timestamp >= startDate, "Auction has not yet started");
        
        if (_secret) {
            require(msg.value > 0, "Ether must be sent for a secret bid");
            require(msg.value == _amount, "Secret bid amount must match the sent value");
            bids[msg.sender] = _amount;
            emit NewBid(msg.sender, _amount, true);
        } else {
            require(msg.value == _amount, "Sent amount does not match the bid");
            if (msg.value > highestBid) {
                highestBid = msg.value;
                winningBidder = msg.sender;
            }
            emit NewBid(msg.sender, msg.value, false);
        }
    }
    
    /**
     Ends the auction manually or automatically.
     It can be called only by the contract owner or automatically after surpassing the end date.
     */
    function endAuction() public onlyOwner {
        require(!auctionEnded, "The auction has already ended");
        require(block.timestamp >= startDate + duration || highestBid >= initialPrice, "Auction has not yet ended");
        
        auctionEnded = true;
        if (highestBid > 0) {
            owner.transfer(highestBid);
            emit AuctionEnded(winningBidder, highestBid);
        }
    }
    
    /**
     Returns the winner of the auction and the winning bid amount.
     */
    function getWinner() public view returns (address, uint256) {
        require(auctionEnded, "The auction has not yet ended");
        return (winningBidder, highestBid);
    }
    
    /**
     Returns the list of bidders and their bid amounts.
     */
    function getBids() public view returns (address[] memory, uint256[] memory) {
        address[] memory bidders = new address[](msg.sender.balance / 100);
        uint256[] memory amounts = new uint256[](msg.sender.balance / 100);
        
        for (uint i = 0; i < bidders.length; i++) {
            bidders[i] = msg.sender;
            amounts[i] = bids[msg.sender];
        }
        
        return (bidders, amounts);
    }
    
    /**
     Allows participants to withdraw their deposit before the end of the auction.
     */
    function withdrawDeposit() public auctionNotEnded {
        uint256 deposit = deposits[msg.sender];
        require(deposit > 0, "No deposit to withdraw");
        
        deposits[msg.sender] = 0;
        payable(msg.sender).transfer(deposit);
    }
    
    /**
     Allows participants to withdraw a percentage of their deposit before the end of the auction.
    _percentage The percentage of the deposit to refund.
     */
    function refund(uint256 _percentage) public auctionNotEnded {
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        uint256 deposit = deposits[msg.sender];
        require(deposit > 0, "No deposit to refund");
        
        uint256 refundAmount = deposit * _percentage / 100;
        deposits[msg.sender] -= refundAmount;
        payable(msg.sender).transfer(refundAmount);
    }
    
    /**
     Allows the contract to receive ether and stores it as a deposit for bids.
     */
    receive() external payable {
        deposits[msg.sender] += msg.value;
    }
}
