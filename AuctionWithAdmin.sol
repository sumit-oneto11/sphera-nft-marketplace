// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./EnumerableMap.sol";

 contract AuctionWithAdmin is Ownable {
    // The NFT token we are selling
    IERC1155 private nft_token;
    // The ERC20 token we are using
    IERC20 private token;

    // beneficiary Address
    address beneficiary;

    using EnumerableMap for EnumerableMap.UintToAddressMap;

    // Declare a set state variable
    EnumerableMap.UintToAddressMap private saleId;
    // Declare a set state variable
    EnumerableMap.UintToAddressMap private auctionId;
    // Declare a set state variable
    EnumerableMap.UintToAddressMap private dealId;

    // Represents an auction on an NFT
    struct AuctionDetails {
        // ID of token
        uint256 tokenId;
        // Price (in token) at beginning of auction
        uint256 price;
        // Time (in seconds) when auction started
        uint256 startTime;
        // Time (in seconds) when auction ended
        uint256 endTime;
        // Address of highest bidder
        address highestBidder;
        // Highest bid amount
        uint256 highestBid;
        // Total number of bids
        uint256 totalBids;
    }

    // Represents an deal on an NFT
    struct DealDetails {
        // NFT Id of Deal
        uint256 tokenId;
        // Price (per token) at beginning of deal
        uint256 price;
        // Quantity (of token) at beginning of deal
        uint256 quantity;
        // Time (in seconds) when deal started
        uint256 startTime;
        // Time (in seconds) when deal ended
        uint256 endTime;
    }

    // Represents an offer on an NFT
    struct OfferDetails {
        // Price (in token) at beginning of auction
        uint256 price;
        // Address of offerer
        address offerer;
        // Address of prevOfferer
        address prevOfferer;
        // Time (in seconds) when offer created
        uint256 time;
    }
    
    // Represents an Bid on Auction NFT
    struct BidDetails {
        // Address of next bidder
        address nextBidder;
        // Address of prev bidder
        address prevBidder;
        // Price (in token) when user place bid
        uint256 amount;
        // Time (in seconds) when bid created
        uint256 time;
    }

    // Mapping token ID to their corresponding auction.
    mapping(uint256 => AuctionDetails) private auction;
    // Mapping token ID to their corresponding deal.
    mapping(uint256 => DealDetails) private deal;
    // Mapping token ID to their corresponding offer.
    mapping(uint256 => OfferDetails) private offer;
    // Mapping from addresss to token ID for claim.
    mapping(address => mapping(uint256 => uint256)) private pending_claim_offer;
    // Mapping from addresss to token ID for claim.
    mapping(address => mapping(uint256 => uint256)) private pending_claim_auction;
    // Mapping from address to token ID for bid
    mapping(address => mapping(uint256 => BidDetails)) public bid_info;
    // Mapping from address to token ID for bid
    mapping(address => mapping(uint256 => OfferDetails)) public offer_info;
    // Mapping from token ID to token price
    mapping(uint256 => uint256) private token_price;
    // Mapping from sale/aution/deal ID to token quantity
    mapping(uint256 => uint256) private token_quantity;
    // Mapping from token ID to sale ID
    mapping(uint256 => uint256) private tokenIdToSaleId;
    

    mapping(address => uint256[]) private saleTokenIds;
    mapping(address => uint256[]) private auctionTokenIds;
    mapping(address => uint256[]) private dealTokenIds;

    uint256 public currentSaleId;
    uint256 public currentAuctionId;
    uint256 public currentDealId;

    uint256 public sell_token_fee;
    uint256 public auction_token_fee;
    uint256 private cancel_bid_fee;
    uint256 private cancel_offer_fee;

    bool private sell_service_fee = false;
    bool private auction_service_fee = false;
    bool private cancel_bid_enable = false;
    bool private cancel_offer_enable = false;
    

    event SellFee(
        uint256 indexed _id,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _time
    );
    event AuctionFee(
        uint256 indexed _id,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _time
    );
    event Sell(
        uint256 indexed _id,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    );
    event SellCancelled(
        uint256 indexed _id,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _time
    );
    event Buy(
        uint256 indexed _id,
        address indexed _buyer,
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _quantity,
        uint256 _time
    );
    event AuctionCreated(
        uint256 indexed _id,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    );
    event Bid(
        uint256 indexed _id,
        address indexed _bidder,
        uint256 indexed _tokenId,
        uint256 _price,
        uint256 _time
    );
    event AuctionCancelled(
        uint256 indexed _id,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _time
    );
    event BidCancelled(
        address indexed _bidder,
        uint256 indexed _auctionId,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _time
    );
    event OfferCancelled(
        address indexed _offerer,
        uint256 _saleId,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _time
    );
    event DealCreated(
        uint256 _dealId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    );
    event BuyDeal(
        uint256 _dealId,
        address indexed _buyer,
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _time
    );
    event DealCancelled(
        uint256 _dealId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _time
    );
    event OfferMaked(
        uint256 indexed _saleId,
        address indexed _offerer,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    );
    event OfferReceived(
        uint256 indexed _saleId,
        address indexed _buyer,
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _time
    );
    event AuctionClaimed(
        uint256 indexed _id,
        address indexed _buyer,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    );
    event OfferClaimed(
        address indexed _buyer,
        uint256 indexed _saleId,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    );

    /// @dev Initialize the nft token contract address.
    /// @param _nftToken - NFT token addess.
    /// @param _token    - ERC20 token addess.
    function initialize(address _nftToken, address _token)
        public
        virtual
        onlyOwner
        returns (bool)
    {
        require(_nftToken != address(0));
        nft_token = IERC1155(_nftToken);
        token = IERC20(_token);
        return true;
    }

    /// @dev Set the beneficiary address.
    /// @param _owner - beneficiary addess.
    function setBeneficiary(address _owner) public onlyOwner {
        beneficiary = _owner;
    }

    /// @dev Contract owner set the token fee percent which is for sell.
    /// @param _tokenFee - Token fee.
    function setTokenFeePercentForSell(uint256 _tokenFee) public onlyOwner {
        sell_token_fee = _tokenFee;
    }

    /// @dev Contract owner set the token fee percent which is for auction.
    /// @param _tokenFee - Token fee.
    function setTokenFeePercentForAuction(uint256 _tokenFee) public onlyOwner {
        auction_token_fee = _tokenFee;
    }

    /// @dev Contract owner set the cancelbid fee percent.
    /// @param _tokenFee - Token fee.
    function setCancelBidFee(uint256 _tokenFee) public onlyOwner {
        cancel_bid_fee = _tokenFee;
    }

    /// @dev Contract owner set the canceloffer fee percent.
    /// @param _tokenFee - Token fee.
    function setCancelOfferFee(uint256 _tokenFee) public onlyOwner {
        cancel_offer_fee = _tokenFee;
    }

    /// @dev Contract owner enables and disable the sell token service fee.
    function sellServiceFee() public onlyOwner {
        sell_service_fee = !sell_service_fee;
    }

    /// @dev Contract owner enables and disable the auction token service fee.
    function auctionServiceFee() public onlyOwner {
        auction_service_fee = !auction_service_fee;
    }

    /// @dev Contract owner enables and disable the cancel bid.
    function cancelBidEnable() public onlyOwner{
        cancel_bid_enable = !cancel_bid_enable;
    }

    /// @dev Contract owner enables and disable the cancel offer.
    function cancelOfferEnable() public onlyOwner{
        cancel_offer_enable = !cancel_offer_enable;
    }

    /// @dev Creates and begins a new auction.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _price - Price of token (in token) at beginning of auction.
    /// @param _startTime - Start time of auction.
    /// @param _endTime - End time of auction.
    function createAuction(
        uint256 _tokenId,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(nft_token.balanceOf(msg.sender, _tokenId)>0, "You are not owner");
        require(nft_token.isApprovedForAll(msg.sender, address(this)), "Token not approved");
        require(_startTime < _endTime && _endTime > block.timestamp, "Check Time");
        require(_price > 0, "Price must be greater than zero");
        currentAuctionId++;
        AuctionDetails memory auctionToken;
        auctionToken = AuctionDetails({
            tokenId: _tokenId,
            price: _price,
            startTime: _startTime,
            endTime: _endTime,
            highestBidder: address(0),
            highestBid: 0,
            totalBids: 0
        });   
        EnumerableMap.set(auctionId, currentAuctionId, msg.sender);
        auction[currentAuctionId] = auctionToken;
        auctionTokenIds[msg.sender].push(_tokenId);
        nft_token.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");
        emit AuctionCreated(currentAuctionId, msg.sender, _tokenId, 1, _price, _startTime, _endTime);
    }

    /// @dev Creates and begins a new deal.
    /// @param _tokenId - ID of token to deal, sender must be owner.
    /// @param _quantity - _quantity of token to deal, sender must be owner.
    /// @param _price - Price of token (per token) at deal.
    /// @param _startTime - Start time of deal.
    /// @param _endTime - End time of deal.
    function createDeal(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner{
        require(nft_token.balanceOf(msg.sender, _tokenId)>=_quantity, "You are not owner");
        require(nft_token.isApprovedForAll(msg.sender, address(this)), "Token not approved");
        require(_startTime < _endTime && _endTime > block.timestamp, "Check Time");
        require(_price > 0, "Price must be greater than zero");

        DealDetails memory dealToken;
        dealToken = DealDetails({
            tokenId: _tokenId,
            price: _price,
            quantity: _quantity,
            startTime: _startTime,
            endTime: _endTime
        });
        currentDealId++;
        deal[currentDealId] = dealToken;
        dealTokenIds[msg.sender].push(_tokenId);
        EnumerableMap.set(dealId, currentDealId, msg.sender);
        nft_token.safeTransferFrom(msg.sender, address(this), _tokenId, _quantity, "");       
        emit DealCreated(currentDealId, msg.sender, _tokenId, _quantity, _price, _startTime, _endTime);
    }

    /// @dev Buy from open sell.
    /// Transfer NFT ownership to buyer address.    
    /// @param _dealId  - Unique Id of Deal.
    function buyDeal(uint256 _dealId) public payable {        
        require(block.timestamp > deal[_dealId].startTime, "Deal not started yet");
        require(block.timestamp < deal[_dealId].endTime, "Deal is over");
        require(EnumerableMap.get(dealId, _dealId)!= address(0) && deal[_dealId].price > 0, "Token not for deal");
        require(msg.sender != EnumerableMap.get(dealId, _dealId), "Owner can't buy");
        uint256 _amount= deal[_dealId].price*deal[_dealId].quantity;
        require(msg.value>=_amount, "Your amount is less");

        nft_token.safeTransferFrom(address(this), msg.sender, deal[_dealId].tokenId, deal[_dealId].quantity, "");
        payable(EnumerableMap.get(dealId, _dealId)).transfer(msg.value);
        emit BuyDeal(_dealId, msg.sender, deal[_dealId].tokenId, EnumerableMap.get(dealId, _dealId), _amount, block.timestamp);
        
        for(uint256 i = 0; i < dealTokenIds[msg.sender].length; i++){
            if(dealTokenIds[msg.sender][i] == deal[_dealId].tokenId){
                dealTokenIds[msg.sender][i] = dealTokenIds[msg.sender][dealTokenIds[msg.sender].length-1];
                delete dealTokenIds[msg.sender][dealTokenIds[msg.sender].length-1];
                break;
            }
        }
        delete deal[_dealId];

        EnumerableMap.remove(dealId, _dealId);
    }

    /// @dev Removes an deal from the list of open deals.
    /// Returns the NFT to original owner.
    /// @param _dealId - Unique Id of NFT on deal.
    function cancelDeal(uint256 _dealId) public onlyOwner {
        require(msg.sender == EnumerableMap.get(dealId, _dealId) || msg.sender == owner(), "You are not owner");
        require(deal[_dealId].price > 0, "Can't cancel this deal");
        nft_token.safeTransferFrom(address(this), EnumerableMap.get(dealId, _dealId), deal[_dealId].tokenId, deal[_dealId].quantity, "");

        for(uint256 i = 0; i < dealTokenIds[EnumerableMap.get(dealId, _dealId)].length; i++){
            if(dealTokenIds[EnumerableMap.get(dealId, _dealId)][i] == deal[_dealId].tokenId){
                dealTokenIds[EnumerableMap.get(dealId, _dealId)][i] = dealTokenIds[EnumerableMap.get(dealId, _dealId)][dealTokenIds[EnumerableMap.get(dealId, _dealId)].length-1];
                delete dealTokenIds[EnumerableMap.get(dealId, _dealId)][dealTokenIds[EnumerableMap.get(dealId, _dealId)].length-1];
                break;
            }
        }    
        
        delete deal[_dealId];    
        EnumerableMap.remove(dealId, _dealId);
        emit DealCancelled(_dealId, msg.sender, deal[_dealId].tokenId, block.timestamp);
    }

    /// @dev Bids on an open auction.
    /// @param _autionId - Unique Id of aution.
    function bid(uint256 _autionId) public payable {    
        require(
            block.timestamp > auction[_autionId].startTime,
            "Auction not started yet"
        );
        require(block.timestamp < auction[_autionId].endTime, "Auction is over");
        require(msg.sender != EnumerableMap.get(auctionId, _autionId), "Owner can't bid in auction");
        // The first bid, ensure it's >= the reserve price.
        if(msg.value < pending_claim_auction[msg.sender][_autionId]){
            //msg.value = pending_claim_auction[msg.sender][_autionId];
        }
        require(
             msg.value >= auction[_autionId].price,
            "Bid must be at least the reserve price"
        );
        // Bid must be greater than last bid.
        require(msg.value > auction[_autionId].highestBid, "Bid amount too low");
       
       
        if(auction[_autionId].highestBidder == msg.sender){
            auction[_autionId].highestBidder = bid_info[msg.sender][_autionId].prevBidder;
            auction[_autionId].totalBids--;
        }else{
            if(bid_info[msg.sender][_autionId].prevBidder == address(0)){
                bid_info[bid_info[msg.sender][_autionId].nextBidder][_autionId].prevBidder = address(0);
            }else{
                bid_info[bid_info[msg.sender][_autionId].prevBidder][_autionId].nextBidder = bid_info[msg.sender][_autionId].nextBidder;
                bid_info[bid_info[msg.sender][_autionId].nextBidder][_autionId].prevBidder = bid_info[msg.sender][_autionId].prevBidder;
            }
        }
        delete bid_info[msg.sender][_autionId];
        
        pending_claim_auction[msg.sender][_autionId] = msg.value;        
        BidDetails memory bidInfo;
        bidInfo = BidDetails({
            prevBidder : auction[_autionId].highestBidder,
            nextBidder : address(0),
            amount     : msg.value,
            time       : block.timestamp
        });
        if(bid_info[auction[_autionId].highestBidder][_autionId].nextBidder == address(0)){
            bid_info[auction[_autionId].highestBidder][_autionId].nextBidder = msg.sender;
        }       
        bid_info[msg.sender][_autionId] = bidInfo;
        pending_claim_auction[msg.sender][_autionId] = msg.value;
        auction[_autionId].highestBidder = msg.sender;
        auction[_autionId].highestBid = msg.value;
        auction[_autionId].totalBids++;
        emit Bid(_autionId, msg.sender, auction[_autionId].tokenId, msg.value, block.timestamp);
    }

    /// @dev Removes the bid from an auction.
    /// Transfer the bid amount to owner.
    /// @param _autionId - Unique Id of auction.
    function cancelBid(uint256 _autionId) public {
        require(cancel_bid_enable, "You can't cancel the bid");
        if(auction[_autionId].highestBidder == msg.sender){
            auction[_autionId].highestBidder = bid_info[msg.sender][_autionId].prevBidder;
            auction[_autionId].highestBid    = bid_info[bid_info[msg.sender][_autionId].prevBidder][_autionId].amount;
        }else{
            if(bid_info[msg.sender][_autionId].prevBidder == address(0)){
                bid_info[bid_info[msg.sender][_autionId].nextBidder][_autionId].prevBidder = address(0);
            }else{
                bid_info[bid_info[msg.sender][_autionId].prevBidder][_autionId].nextBidder = bid_info[msg.sender][_autionId].nextBidder;
                bid_info[bid_info[msg.sender][_autionId].nextBidder][_autionId].prevBidder = bid_info[msg.sender][_autionId].prevBidder;
            }
        }
        delete bid_info[msg.sender][_autionId];
        auction[_autionId].totalBids--;
        emit BidCancelled(msg.sender, _autionId, auction[_autionId].tokenId, pending_claim_auction[msg.sender][_autionId] - (pending_claim_auction[msg.sender][_autionId] * (cancel_bid_fee / 100)), block.timestamp);
        token.transfer(msg.sender, pending_claim_auction[msg.sender][_autionId] - (pending_claim_auction[msg.sender][_autionId] * (cancel_bid_fee / 100)));       
        pending_claim_auction[msg.sender][_autionId] = 0;        
    }

    /// @dev Cancel the Offer.
    /// Transfer the offer amount to owner.
    /// @param _tokenId - ID of NFT on sell.
    function cancelOffer(uint256 _tokenId) public {
        require(cancel_offer_enable, "You can't cancel the offer");
        if(offer[_tokenId].offerer == msg.sender){
            offer[_tokenId].offerer = offer_info[msg.sender][_tokenId].prevOfferer;
            offer[_tokenId].price   = offer_info[offer_info[msg.sender][_tokenId].prevOfferer][_tokenId].price;
        }else{
            if(offer_info[msg.sender][_tokenId].prevOfferer == address(0)){
                offer_info[offer_info[msg.sender][_tokenId].offerer][_tokenId].prevOfferer = address(0);
            }else{
                offer_info[offer_info[msg.sender][_tokenId].prevOfferer][_tokenId].offerer = offer_info[msg.sender][_tokenId].offerer;
                offer_info[offer_info[msg.sender][_tokenId].offerer][_tokenId].prevOfferer = offer_info[msg.sender][_tokenId].prevOfferer;
            }
        }
        delete offer_info[msg.sender][_tokenId];
        emit OfferCancelled(msg.sender, tokenIdToSaleId[_tokenId], _tokenId, pending_claim_offer[msg.sender][_tokenId] - (pending_claim_offer[msg.sender][_tokenId] * (cancel_offer_fee / 100)), block.timestamp);
        token.transfer(msg.sender, pending_claim_offer[msg.sender][_tokenId] - (pending_claim_offer[msg.sender][_tokenId] * (cancel_offer_fee / 100)));       
        pending_claim_offer[msg.sender][_tokenId] = 0;        
    }

    /// @dev Offer on an sell.
    /// @param _tokenId - ID of token to offer on.
    /// @param _amount  - Offerer set the price (in token) of NFT token.
    function makeOffer(uint256 _tokenId, uint256 _amount) public {             
        require(
            EnumerableMap.get(saleId, _tokenId) != address(0) && token_price[_tokenId] > 0,
            "Token not for sell"
        );
        require(msg.sender != EnumerableMap.get(saleId, _tokenId), "Owner can't make the offer");
        if(_amount < pending_claim_offer[msg.sender][_tokenId]){
            _amount = pending_claim_offer[msg.sender][_tokenId];
        }
        // Offer must be greater than last offer.
        require(
            _amount > offer[_tokenId].price,
            "Offer amount less then already offerred"
        );
        token.transferFrom(msg.sender, address(this), _amount - pending_claim_offer[msg.sender][_tokenId]);
        if(offer[_tokenId].offerer == msg.sender){
            offer[_tokenId].offerer = offer_info[msg.sender][_tokenId].prevOfferer;
        }else{
            if(offer_info[msg.sender][_tokenId].prevOfferer == address(0)){
                offer_info[offer_info[msg.sender][_tokenId].offerer][_tokenId].prevOfferer = address(0);
            }else{
                offer_info[offer_info[msg.sender][_tokenId].prevOfferer][_tokenId].offerer = offer_info[msg.sender][_tokenId].offerer;
                offer_info[offer_info[msg.sender][_tokenId].offerer][_tokenId].prevOfferer = offer_info[msg.sender][_tokenId].prevOfferer;
            }
        }
        delete offer_info[msg.sender][_tokenId];       
        OfferDetails memory offerInfo;
        offerInfo = OfferDetails({
            prevOfferer : offer[_tokenId].offerer,
            offerer     : address(0),
            price       : _amount,
            time        : block.timestamp
        });
        if(offer_info[offer[_tokenId].offerer][_tokenId].offerer == address(0)){
            offer_info[offer[_tokenId].offerer][_tokenId].offerer = msg.sender;
        }       
        offer_info[msg.sender][_tokenId] = offerInfo;
        pending_claim_offer[msg.sender][_tokenId] = _amount;
        offer[_tokenId].prevOfferer = offer[_tokenId].offerer;
        offer[_tokenId].offerer = msg.sender;
        offer[_tokenId].price = _amount;
        emit OfferMaked(tokenIdToSaleId[_tokenId], msg.sender, _tokenId, _amount, block.timestamp);
    }

    /// @dev Receive offer from open sell.
    /// Transfer NFT ownership to offerer address.
    /// @param _tokenId - ID of NFT on offer.
    function reciveOffer(uint256 _tokenId) public {
        require(msg.sender ==  EnumerableMap.get(saleId, _tokenId), "You are not owner");
        nft_token.safeTransferFrom(
            address(this),
            offer[_tokenId].offerer,
            _tokenId,
            1,
            ""
        );
        if(sell_service_fee == true){   
            token.transfer(
                beneficiary,
                ((offer[_tokenId].price * sell_token_fee) / 100)
            );
            emit SellFee(
                tokenIdToSaleId[_tokenId],
                _tokenId,
                ((offer[_tokenId].price * sell_token_fee) / 100),
                block.timestamp
            );
            token.transfer(
                EnumerableMap.get(saleId, _tokenId),
                ((offer[_tokenId].price * (100 - sell_token_fee)) / 100)
            );
        }else{
            token.transfer(
                EnumerableMap.get(saleId, _tokenId),
                offer[_tokenId].price
            );
        }
        for(uint256 i = 0; i < saleTokenIds[msg.sender].length; i++){
            if(saleTokenIds[msg.sender][i] == _tokenId){
                saleTokenIds[msg.sender][i] = saleTokenIds[msg.sender][saleTokenIds[msg.sender].length-1];
                delete saleTokenIds[msg.sender][saleTokenIds[msg.sender].length-1];
                break;
            }
        }
        delete token_price[_tokenId];       
        EnumerableMap.remove(saleId, _tokenId);
        pending_claim_offer[offer[_tokenId].offerer][_tokenId] = 0;
        emit OfferReceived(
            tokenIdToSaleId[_tokenId],
            offer[_tokenId].offerer,
            _tokenId,
            msg.sender,
            offer[_tokenId].price,
            block.timestamp
        );
        delete offer_info[offer[_tokenId].offerer][_tokenId];
        delete offer[_tokenId];
        delete tokenIdToSaleId[_tokenId];       
    }
    

    /// @dev Create claim after auction ends.
    /// Transfer NFT to auction winner address.
    /// Seller and Bidders (not win in auction) Withdraw their funds.
    /// @param _tokenId - ID of NFT.
    function auctionClaim(uint256 _tokenId) public {
        require(
           auction[_tokenId].endTime < block.timestamp,
            "auction not compeleted yet"
        );
        require(
            auction[_tokenId].highestBidder == msg.sender || msg.sender == EnumerableMap.get(auctionId, _tokenId) || msg.sender == owner(),
            "You are not highest Bidder or owner"
        );
        
        if(auction_service_fee == true){
            token.transfer(
                beneficiary,
                ((auction[_tokenId].highestBid * auction_token_fee) / 100)
            );
            emit AuctionFee(auction[_tokenId].tokenId, _tokenId, ((auction[_tokenId].highestBid * auction_token_fee) / 100), block.timestamp);
            token.transfer(
                EnumerableMap.get(auctionId, _tokenId),
                ((auction[_tokenId].highestBid * (100 - auction_token_fee)) /
                    100)
            );
        }else{
            token.transfer(
                EnumerableMap.get(auctionId, _tokenId),
                auction[_tokenId].highestBid
            );
        }
        pending_claim_auction[auction[_tokenId].highestBidder][_tokenId] = 0;
        nft_token.safeTransferFrom(address(this), auction[_tokenId].highestBidder, _tokenId, 1, "");          
        emit AuctionClaimed(auction[_tokenId].tokenId, msg.sender, _tokenId, auction[_tokenId].highestBid, block.timestamp);
        for(uint256 i = 0; i < auctionTokenIds[msg.sender].length; i++){
            if(auctionTokenIds[msg.sender][i] == _tokenId){
                auctionTokenIds[msg.sender][i] = auctionTokenIds[msg.sender][auctionTokenIds[msg.sender].length-1];
                delete auctionTokenIds[msg.sender][auctionTokenIds[msg.sender].length-1];
                break;
            }
        }
        delete auction[_tokenId];
        EnumerableMap.remove(auctionId, _tokenId);      
    }

    /// @dev Create claim after auction claim.
    /// bidders (not win in auction) Withdraw their funds.
    /// @param _tokenId - ID of NFT.
    function auctionPendingClaim(uint256 _tokenId) public {
        require(auction[_tokenId].highestBidder != msg.sender && auction[_tokenId].endTime < block.timestamp, "Your auction is running");
        require(pending_claim_auction[msg.sender][_tokenId] != 0, "You are not a bidder or already claimed");
        token.transfer(msg.sender, pending_claim_auction[msg.sender][_tokenId]);
        emit AuctionClaimed(0, msg.sender, _tokenId, pending_claim_auction[msg.sender][_tokenId], block.timestamp);
        delete bid_info[msg.sender][_tokenId];
        pending_claim_auction[msg.sender][_tokenId] = 0;
    }

    /// @dev Create claim after offer claim.
    /// Offerers (not win in offer) Withdraw their funds.
    /// @param _tokenId - ID of NFT.
    function offerClaim(uint256 _tokenId) public {
        require(offer[_tokenId].offerer != msg.sender, "Your offer is running");
        require(pending_claim_offer[msg.sender][_tokenId] != 0, "You are not a offerer or already claimed");
        token.transfer(msg.sender, pending_claim_offer[msg.sender][_tokenId]);       
        emit OfferClaimed(msg.sender, tokenIdToSaleId[_tokenId], _tokenId, pending_claim_offer[msg.sender][_tokenId], block.timestamp);
        delete offer_info[msg.sender][_tokenId];
        pending_claim_offer[msg.sender][_tokenId] = 0;
    }

    /// @dev Returns auction info for an NFT on auction.
    /// @param _tokenId - ID of NFT on auction.
    function getAuction(uint256 _tokenId)
        public
        view
        virtual
        returns (AuctionDetails memory)
    {
        return (auction[_tokenId]);
    }

    /// @dev Returns auction info for an NFT on auction.
    /// @param _tokenId - ID of NFT on auction.
    function getpending_claim_auction(address _user, uint256 _tokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return pending_claim_auction[_user][_tokenId];
    }

    /// @dev Returns offer info for an NFT on offer.
    /// @param _tokenId - ID of NFT on offer.
    function getpending_claim_offer(address _user, uint256 _tokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return pending_claim_offer[_user][_tokenId];
    }

    /// @dev Returns sell NFT token price.
    /// @param _tokenId - ID of NFT.
    function getSellTokenPrice(uint256 _tokenId) public view returns (uint256) {
        return token_price[_tokenId];
    }


    /// @dev Buy from open sell.
    /// Transfer NFT ownership to buyer address.
    /// @param _saleId  - unique saleId of token.
    /// @param _quantity  - token quantity buyer wants to buy.
    function buy(uint256 _saleId, uint256 _quantity) public payable {
        require(msg.sender != EnumerableMap.get(saleId, _saleId), "Owner can't buy");
        require(EnumerableMap.get(saleId, _saleId) != address(0) && token_price[_saleId] > 0, "Token not for sell");
        uint256 _sellAmount= token_price[_saleId]*_quantity;
        require(msg.value >= _sellAmount, "Your amount is less");  
        uint256 _tokenId = tokenIdToSaleId[_saleId];
        nft_token.safeTransferFrom(address(this), msg.sender, _tokenId, _quantity, "");

        if(sell_service_fee == true){
            emit SellFee(_saleId, _tokenId, ((_sellAmount * sell_token_fee) / 100), block.timestamp);
            payable(EnumerableMap.get(saleId, _saleId)).transfer(((_sellAmount * (100 - sell_token_fee)) / 100)); 
        }
        else{
            payable(EnumerableMap.get(saleId, _saleId)).transfer(_sellAmount); 
        }  

        emit Buy(tokenIdToSaleId[_tokenId], msg.sender, _tokenId, EnumerableMap.get(saleId, _tokenId), _sellAmount, _quantity, block.timestamp);

        if(_quantity<token_quantity[_saleId])
        {
           token_quantity[_saleId]=token_quantity[_saleId]-_quantity;     
        }
        else
        {
            delete token_quantity[_saleId];
            delete token_price[_saleId];
            delete tokenIdToSaleId[_saleId];
            delete offer[_saleId];
            EnumerableMap.remove(saleId, _saleId); 
        }
        
        for(uint256 i = 0; i < saleTokenIds[msg.sender].length; i++){
            if(saleTokenIds[msg.sender][i] == _tokenId){
                saleTokenIds[msg.sender][i] = saleTokenIds[msg.sender][saleTokenIds[msg.sender].length-1];
                delete saleTokenIds[msg.sender][saleTokenIds[msg.sender].length-1];
                break;
            }
        }             
    }

    /// @dev Creates a new sell.
    /// Transfer NFT ownership to this contract.
    /// @param _tokenId - ID of NFT on sell.
    /// @param _price   - Seller set the price (in token) of NFT token.
    function sell(uint256 _tokenId, uint256 _price, uint256 _quantity) public {
        require(nft_token.balanceOf(msg.sender, _tokenId)>0, "You are not owner");
        require(nft_token.isApprovedForAll(msg.sender, address(this)), "Token not approved");
        require(_price > 0 && _quantity>0, "Price & Quantity must be greater than zero");        
        currentSaleId++;
        token_price[currentSaleId] = _price;
        token_quantity[currentSaleId] = _quantity;
        tokenIdToSaleId[currentSaleId] = _tokenId;
        EnumerableMap.set(saleId, currentSaleId, msg.sender);
        saleTokenIds[msg.sender].push(_tokenId);
        nft_token.safeTransferFrom(msg.sender, address(this), _tokenId, _quantity, "");
        emit Sell(currentSaleId, msg.sender, _tokenId, _price, block.timestamp);
    }

    /// @dev Removes token from the list of open sell.
    /// Returns the NFT to original owner.
    /// @param _saleId - unique saleId of token.
    function cancelSell(uint256 _saleId) public {
        require(msg.sender ==  EnumerableMap.get(saleId, _saleId) || msg.sender == owner(), "You are not owner");
        require(token_price[_saleId] > 0, "Can't cancel the sell");
        uint256 _tokenId = tokenIdToSaleId[_saleId];
        nft_token.safeTransferFrom(address(this), EnumerableMap.get(saleId, _saleId),  _tokenId, 1, "");
        delete token_price[_saleId];
        currentSaleId--;
        for(uint256 i = 0; i < saleTokenIds[EnumerableMap.get(saleId, _saleId)].length; i++){
            if(saleTokenIds[EnumerableMap.get(saleId, _saleId)][i] == _tokenId){
                saleTokenIds[EnumerableMap.get(saleId, _saleId)][i] = saleTokenIds[EnumerableMap.get(saleId, _saleId)][saleTokenIds[EnumerableMap.get(saleId, _saleId)].length-1];
                delete saleTokenIds[EnumerableMap.get(saleId, _saleId)][saleTokenIds[EnumerableMap.get(saleId, _saleId)].length-1];
                break;
            }
        }
        EnumerableMap.remove(saleId, _saleId);      
        emit SellCancelled(_saleId, msg.sender, _tokenId, block.timestamp);
        delete tokenIdToSaleId[_saleId];
    }

    /// @dev Removes an auction from the list of open auctions.
    /// Returns the NFT to original owner.
    /// @param _auctionId - ID of NFT on auction.
    function cancelAuction(uint256 _auctionId) public {
        require(msg.sender ==  EnumerableMap.get(auctionId, _auctionId) || msg.sender == owner(), "You are not owner");
        nft_token.safeTransferFrom(address(this), EnumerableMap.get(auctionId, _auctionId), auction[_auctionId].tokenId, 1, "");
        for(uint256 i = 0; i < auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)].length; i++){
            if(auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)][i] == auction[_auctionId].tokenId){
                auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)][i] = auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)][auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)].length-1];
                delete auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)][auctionTokenIds[EnumerableMap.get(auctionId, _auctionId)].length-1];
                break;
            }
        }
        EnumerableMap.remove(auctionId, _auctionId);
        emit AuctionCancelled(_auctionId, msg.sender, auction[_auctionId].tokenId, block.timestamp);
        delete auction[_auctionId];
    }

    /// @dev Returns the user sell token Ids.
    function getSaleTokenId(address _user) public view returns(uint256[] memory){
        return saleTokenIds[_user];
    }

    /// @dev Returns the user auction token Ids.
    function getAuctionTokenId(address _user) public view returns(uint256[] memory){
        return auctionTokenIds[_user];
    }

    /// @dev Returns the user deal token Ids
    function getDealTokenId(address _user) public view returns(uint256[] memory){
        return dealTokenIds[_user];
    }

    /// @dev Returns the total deal length.
    function totalDeal() public view returns (uint256){
        return EnumerableMap.length(dealId);
    }

    /// @dev Returns the total sale length.
    function totalSale() public view returns (uint256){
        return EnumerableMap.length(saleId);
    }

    /// @dev Returns the total auction length.
    function totalAuction() public view returns (uint256){
        return EnumerableMap.length(auctionId);
    }

    /// @dev Returns the deal details and token Id.
    /// @param index - Index of NFT on deal.
    function dealDetails(uint256 index) public view returns (DealDetails memory dealInfo, uint256 tokenId){
        (uint256 id,) = EnumerableMap.at(dealId, index);
        return (deal[id], id);
    }

    /// @dev Returns the offer details, seller address ,token Id and price.
    /// @param index - Index of NFT on sale.
    function saleDetails(uint256 index) public view returns (OfferDetails memory offerInfo, address seller, uint256 tokenId, uint256 price){
        (uint256 id,) = EnumerableMap.at(saleId, index);
        return (offer[id], EnumerableMap.get(saleId, id), id, token_price[id]);
    }

    /// @dev Returns the auction details and token Id.
    /// @param index - Index of NFT on auction.
    function auctionDetails(uint256 index) public view returns (AuctionDetails memory auctionInfo, uint256 tokenId){
        (uint256 id,) =  EnumerableMap.at(auctionId, index);        
        return (auction[id], id);
    }

    /// @dev Returns sale and offer details on the basis of tokenId.
    /// @param tokenId - Id of NFT on sale.
    function saleDetailsByTokenId(uint256 tokenId) public view returns (OfferDetails memory offerInfo, address seller, uint256 price){             
        return (offer[tokenId], EnumerableMap.get(saleId, tokenId), token_price[tokenId]);
    }

    /// @dev Returns deal details on the basis of tokenId.
    /// @param tokenId - Id of NFT on deal.
    function dealDetailsByTokenId(uint256 tokenId) public view returns (DealDetails memory dealInfo){             
        return (deal[tokenId]);
    }

    /// @dev Returns all auction details.
    function getAllAuctionInfo() public view returns (AuctionDetails[] memory) {
        AuctionDetails[] memory auctionInfo = new AuctionDetails[](EnumerableMap.length(auctionId));
        for(uint256 i = 0; i < EnumerableMap.length(auctionId); i++){
            (uint256 id,) =  EnumerableMap.at(auctionId, i);  
            auctionInfo [i] = (auction[id]);
        }
        return auctionInfo;
    }

    /// @dev Returns all deal details.
    function getAllDealInfo() public view returns (DealDetails[] memory) {
        DealDetails[] memory dealInfo = new DealDetails[](EnumerableMap.length(dealId));
        for(uint256 i = 0; i < EnumerableMap.length(dealId); i++){
            (uint256 id,) =  EnumerableMap.at(dealId, i);  
            dealInfo [i] = (deal[id]);
        }
        return dealInfo;
    }

    /// @dev Returns all sale details.
    function getAllSaleInfo() public view returns(OfferDetails[] memory, address[] memory seller, uint256[] memory price, uint256[] memory tokenIds){
        OfferDetails[] memory offerInfo = new OfferDetails[](EnumerableMap.length(saleId));
        for(uint256 i = 0; i < EnumerableMap.length(saleId); i++){
            (uint256 id,) =  EnumerableMap.at(saleId, i);  
            offerInfo [i] = (offer[id]);
            seller[i] = EnumerableMap.get(saleId, id);
            price[i] =  token_price[id];
            tokenIds[i] = id;
        }
        return (offerInfo, seller, price, tokenIds);
    }

    /// @dev Returns string for token place in which market.
    /// @param tokenId - Id of NFT.
    function checkMarket(uint256 tokenId) public view returns(string memory){
        if(auction[tokenId].price > 0){
            return "Auction";
        }else if(deal[tokenId].price > 0){
            return "Deal";
        }else if(token_price[tokenId] > 0){
            return "Sale";
        }else{
            return "Not in market";
        }
    }

    function getCancelBidEnabled() public view returns(bool){
        return cancel_bid_enable;
    }

    function getCancelOfferEnabled() public view returns(bool){
        return cancel_offer_enable;
    }
}
