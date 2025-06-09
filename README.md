#  Enhanced Auction Smart Contract

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.0-blue.svg)](https://docs.soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ethereum](https://img.shields.io/badge/Ethereum-Compatible-green.svg)](https://ethereum.org/)

A decentralized auction smart contract implemented in Solidity 

> **📖 Educational Implementation**  
> This smart contract is a practical work assignment showcasing the implementation of a complete auction system with advanced features like automated refunds, time extensions, and commission handling.


##  Features

- **Deposit-based bidding**: Participants deposit ETH to place their bids
- **Automatic refunds**: Losers receive their money back automatically
- **2% commission**: Contract owner receives a transaction commission
- **Automatic time extension**: Bids in the last 10 minutes extend the auction
- **Partial refunds**: Users can recover previous bids (except current winner)
- **Role separation**: Distinction between contract owner and item seller
- **5% minimum increase**: New bids must be at least 5% higher
- **Reentrancy protection**: Secure implementation of transfers

##  State Variables

### Constants

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `MIN_INCREASE_PERCENTAGE` | `uint256` | 5 | Minimum percentage increase per bid |
| `EXTENSION_TIME` | `uint256` | 10 minutes | Automatic extension time |
| `COMMISSION_PERCENTAGE` | `uint256` | 2 | Commission percentage for owner |

### Main Variables

| Variable | Type | Visibility | Description |
|----------|------|------------|-------------|
| `owner` | `address` | `public` | Contract owner address |
| `seller` | `address` | `public` | Address that receives item payment |
| `itemDescription` | `string` | `public` | Description of the auctioned item |
| `startTime` | `uint` | `public` | Auction start timestamp |
| `endTime` | `uint` | `public` | Auction end timestamp |
| `highestBidder` | `address` | `public` | Current highest bidder address |
| `highestBid` | `uint` | `public` | Current highest bid amount |
| `ended` | `bool` | `public` | Indicates if auction has ended |
| `refundsProcessed` | `bool` | `public` | Prevents double refund processing |

### Mappings and Arrays

| Variable | Type | Description |
|----------|------|-------------|
| `bids` | `mapping(address => uint)` | Maps addresses to their total bids |
| `validBids` | `mapping(address => uint[])` | Maps addresses to their valid bids for refund |
| `bidders` | `address[]` | Array of all addresses that have placed bids |

##  Core Functions

### Constructor

```solidity
constructor(
    string memory _itemDescription, 
    uint _durationInMinutes,
    address _seller
)
```

**Parameters:**
- `_itemDescription`: Description of the auctioned item
- `_durationInMinutes`: Auction duration in minutes
- `_seller`: Address that will receive payment (can be different from owner)

**Validations:**
- Seller address cannot be zero
- Duration must be greater than zero

### Bidding Functions

#### `bid()`
```solidity
function bid() public payable onlyActive
```

Allows users to place bids in the auction.

**Features:**
- Requires bid to be at least 5% higher than current
- Automatically extends time if less than 10 minutes remain
- Saves user's bid history
- Emits `NewBid` event

#### `requestPartialRefund()`
```solidity
function requestPartialRefund() public onlyActive
```

Allows users to recover their previous bids (except current winner).

**Restrictions:**
- Current winner cannot request partial refund
- Can only refund previous bids, not current one
- Emits `PartialRefundIssued` event

### Finalization Functions

#### `endAuction()`
```solidity
function endAuction() public onlyOwner
```

Manually ends the auction (owner only).

**Process:**
1. Marks auction as ended
2. Processes refunds automatically
3. Transfers commission to owner
4. Transfers payment to seller

#### `processRefundsManually()`
```solidity
function processRefundsManually() public onlyEnded
```

Manually processes refunds if not done automatically.

### Query Functions

#### `getWinner()`
```solidity
function getWinner() public view onlyEnded returns (address, uint)
```

Returns winner's address and winning amount.

#### `getAllBids()`
```solidity
function getAllBids() public view returns (address[] memory, uint[] memory)
```

Returns arrays with all addresses and their current bids.

#### `getRemainingTime()`
```solidity
function getRemainingTime() public view returns (uint)
```

Returns remaining auction time in seconds.

#### `getAuctionInfo()`
```solidity
function getAuctionInfo() public view returns (...)
```

Returns complete auction information.

#### `getValidBids(address bidder)`
```solidity
function getValidBids(address bidder) public view returns (uint[] memory)
```

Returns valid bid history for a specific user.

## Events

### `NewBid`
```solidity
event NewBid(address indexed bidder, uint amount, uint timestamp);
```

Emitted when a new bid is placed.

### `AuctionEnded`
```solidity
event AuctionEnded(address winner, uint amount, uint timestamp);
```

Emitted when the auction ends.

### `RefundIssued`
```solidity
event RefundIssued(address bidder, uint amount);
```

Emitted when a refund is processed to a loser.

### `PartialRefundIssued`
```solidity
event PartialRefundIssued(address bidder, uint amount);
```

Emitted when a partial refund is processed.

### `PaymentProcessed`
```solidity
event PaymentProcessed(address seller, uint amount, address owner, uint commission);
```

Emitted when final payments are processed.

##  Modifiers

### `onlyActive`
Verifies that the auction is active:
- Has started (`block.timestamp >= startTime`)
- Has not ended (`block.timestamp < endTime`)
- Has not been manually ended (`!ended`)

### `onlyEnded`
Verifies that the auction has ended:
- Time has expired OR has been manually ended

### `onlyOwner`
Restricts function to contract owner only.

## License

This project is licensed under the MIT License

## Contact

If you have questions or need help:

- 📧 My Email: aramayo.fabian@gmail.com
