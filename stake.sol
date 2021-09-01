//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


// import "https://github.com/Scott6768/LottoescapeV2/blob/main/LottoescapeV2";
import "./LSC.sol";
//import "";


contract LottoGame {
    uint perTicketPrice;
    using SafeMath for uint256; 
    
    address[5] winners; //payable[]  public  winners; 
    uint public numWinners;
    bool terminator; //flag for stopping the game in its tracks
    
    uint public potValue;
    uint public potRemaining;
    
    mapping(address => uint) public ticketBalance; 
    
    mapping(address => uint) public profits; 
    
    uint public totalTickets; 
    
    address public owner;
    address internal _tokenAddress;
    
    uint public amountToSendToNextRound; 
    uint amountToMarketingAddress;
    uint amountToSendToLiquidity; 
    
    //uint public timeLeft; 
    uint public startTime; 
    uint public endTime; 
    uint public roundNumber; // to keep track of the active round of play
    
    address public liquidityTokenRecipient;
    
    LSC public token;
    
    
    IPancakeRouter02 public pancakeswapV2Router;
    uint256 minimumBuy; //minimum buy to be eligible to win share of the pot
    uint256 tokensToAddOneSecond; //number of tokens that will add one second to the timer
    uint256 maxTimeLeft; //maximum number of seconds the timer can be
    uint256 maxWinners; //number of players eligible for winning share of the pot
    uint256 potPayoutPercent; // what percent of the pot is paid out
    uint256 potLeftoverPercent; // what percent is leftover 
    uint256 maxTickets; // max amount of tickets a player can hold
        
    uint[5] winnerProfits;
    uint[5] bnbProfits;
    
    //optional stuff for fixing code later
    address public _liquidityAddress = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3; //set to proper address if you need to pull V2 router manually
    address public _marketingAddress = 0x54b360304374156D80C49b97a820836f89655360; //set to proper marketing address

    constructor() public {
        _tokenAddress = 0x2c0B1c005c54924eB53B4C3fD1650690BA01C128;

        token = LSC(payable(_tokenAddress));
        
        //pancakeswapV2Router = 0xB8D16214aD6Cb0E4967c3aeFCc8Bc5f74D386B0a; //The lazy way
        pancakeswapV2Router = token.pancakeswapV2Router(); // pulls router information directly from main contract

        // BUT, JUST IN CAST ^^THAT DOESN'T WORK:
        /*/ Taken from standard code base, you also might try pulling v2pair and running with that.
        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(_liquidityAddress);
        //Create a Pancake pair for this new token
        address pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
            .createPair(address(this), _pancakeswapV2Router.WETH());
        //set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;
        //*/
        
        owner = msg.sender; 
        //liquidityTokenRecipient = address(this); 
        liquidityTokenRecipient = _liquidityAddress;

        //set initial game gameSettings
        minimumBuy = 100000*10**9; 
        tokensToAddOneSecond = 1000*10**9;
        maxTimeLeft = 300 seconds;
        maxWinners = 5; 
        potPayoutPercent = 60;
        potLeftoverPercent = 40;
        maxTickets = 10;
    }
    
    receive() external payable {
        //to be able to receive eth/bnb
    }
    
    function getGameSettings() public view returns (uint, uint, uint, uint, uint) {
        return (minimumBuy, tokensToAddOneSecond, maxTimeLeft, maxWinners, potPayoutPercent);
    }
    
    function adjustBuyInAmount(uint newBuyInAmount) external {
        //add new buy in amount with 9 extra zeroes when calling this function (your token has 9 decimals)
        require(msg.sender == owner, "Only owner");
        minimumBuy = newBuyInAmount;
    }
    
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner.");
        require(newOwner != address(0), "Address of owner cannot be zero.");
        owner = newOwner; 
    }
    
    function changeLiqduidityTokenRecipient(address newRecipient) public {
        require(msg.sender == owner, "Only owner"); 
        require(newRecipient != address(0), "Address of recipient cannot be zero.");
        _liquidityAddress = newRecipient;
        liquidityTokenRecipient = _liquidityAddress;
    }
    
    function buyTicket(address payable buyer, uint amount) public {
        require(endTime != 0, "Game is not active!");  // will set when owner starts the game with initializeAndStart()
        require(amount >= minimumBuy, "You must bet a minimum of 100,000 tokens.");
        require(amount.div(minimumBuy * 10) <= maxTickets, "You may only purchase 10 tickets per play");
        require(token.balanceOf(msg.sender) >= amount, "You don't have enough tokens"); //check the owners wallet to make sure they have enough
        //note this function will throw unless a ticket is purchased!!
        
        // start a new round if needed
        uint startflag = getTimeLeft();
        // getTimeLeft() returns 0 if the game has ended
        if (startflag == 0) {
            endGame();
        } else {  //if startflag is NOT equal to zero, game carries on
            bool alreadyPlayed = false; //set this as a flag inside of the if
            for (uint i = 0; i < numWinners; i++) { //scroll through the winners list
                if (buyer == winners[i]){
                    alreadyPlayed = true;
                }
            }
            //This statement is the whole point of the ELSE block, just make sure they aren't on the board
            //If you need to remove their previous bet and add a new one, do it here.
            //add a flag above for the index and squish it.
            require(alreadyPlayed == false, "You can only buy tickets if you don't have a valid bid on the board");
        }
        
        ticketBalance[buyer] += amount.div(100000*10**9);
        require(ticketBalance[buyer] >= 1, "Not enough for a ticket");
        
        if (numWinners < maxWinners) {
            // Only 5 winners allowed on the board, so if we haven't met that limit then add to the stack
            winners[numWinners] = payable(buyer);
            numWinners++;
        } else {
            //add new buyer and remove the first from the stack
            ticketBalance[winners[0]] = 0;
            for (uint i=0; i < (maxWinners - 1); i++){ //note the -1, we only want the leading values
                winners[i] = winners[i+1]; 
            }
            winners[numWinners - 1] = payable(buyer);  //now we add the stake to the top
        }
        
        uint timeToAdd = amount.div(tokensToAddOneSecond);
        addTime(timeToAdd);
        
        // Transfer Approval is handled by Web 3 before sending
        // approve(this contract, amount)
        token.transferFrom(msg.sender, payable(address(this)), amount);
        
        //token.transferLSCgame2(msg.sender, payable(address(this)), amount);
        potValue += amount;
    }
    
    function localTokenBalance() public view returns(uint){
        return token.balanceOf(address(this));
    }
    
    function getTimeLeft() public view returns (uint){
        if (now >= endTime) {
            //endGame(); This would cost gas for the calling wallet or function, not good, but it would be an auto-start not requiring a new bid 
            // IF this returns 0, then you can add the "Buy ticket to start next round" and the gas from that ticket will start the next round
            // see buyTicket for details
            return 0;
        }else
        return endTime - now; 
    }
        
    function addTime(uint timeAmount) private {
        endTime += timeAmount;
        if ((endTime - now) > maxTimeLeft) {
            endTime = now + maxTimeLeft;
        }
    }
    
    function initializeAndStart() external {
        require(msg.sender == owner, "Only the contract owner can start the game");
        roundNumber = 0;
        startGame();
    }
    
    function startGame() private {
        require(endTime <= now, "Stop spamming the start button please.");
        roundNumber++;
        startTime = now;
        endTime = now + maxTimeLeft;
        winners = [address(0), address(0), address(0), address(0), address(0)];
        numWinners = 0;
    }
    
    function endGame() private {
        require(now >= endTime, "Game is still active");
        potRemaining = setPayoutAmount(); //does not change pot Value
        require (potRemaining > 0, "potRemaining is 0!");
        dealWithLeftovers(potRemaining);
        sendProfitsInBNB();
        swapAndAddLiqduidity();
        
        potValue = amountToSendToNextRound;
        if (amountToMarketingAddress > 0) {
            // token.transfer(payable(_marketingAddress), (amountToMarketingAddress));
            token.transferLSCgame2(address(this), payable(_marketingAddress), (amountToMarketingAddress));
        }
        
        for (uint i = 0; i < numWinners; i++) {
            ticketBalance[winners[i]] = 0;
            winners[i] = address(0);
        }
        
        if (terminator == false){
            startGame();
        } else { terminator = false; }
        
    }
    
    function setPayoutAmount() private returns(uint){
        //get number of tickets held by each winner in the array 
        //only run once per round or tickets will be incorrectly counted
        //this is handled by endGame(), do not call outside of that pls and thnx
        totalTickets = 0; //reset before you start counting
        for (uint i = 0; i < numWinners; i++) {
           totalTickets += ticketBalance[winners[i]];
        }
        //require (totalTickets > 0, "Total Tickets is 0!");
        //uint perTicketPrice;
        uint top = (potValue.mul(potPayoutPercent));
        uint bottom = (totalTickets.mul(100));
        
        //require(bottom > 0, "Something has gone horribly wrong.");
        if (bottom > 0){
            perTicketPrice = top / bottom;
        }
        
        uint tally = 0;
        //calculate the winnings based on how many tickets held by each winner
        
        for (uint i; i < numWinners; i++){
            winnerProfits[i] = perTicketPrice * ticketBalance[winners[i]];
            tally += winnerProfits[i];
            if (winnerProfits[i] > 0) {
                bnbProfits[i] = swapProfitsForBNB(winnerProfits[i]);
            }
        }
        
        require (tally < potValue, "Tally is bigger than the pot!");
        return (potValue - tally);
    }
    
    function preLoadPot(uint amount) public { //This needs to be fixed also
        //token.outsideApprove(msg.sender, address(this), amount);
        // token.transferFrom(msg.sender, payable(address(this)), amount);
        token.transferLSCgame2(msg.sender, payable(address(this)), amount);
        potValue += amount;
    }
    
    function swapProfitsForBNB(uint amount) private returns (uint256) {
            address[] memory path = new address[](2);
            path[0] = _tokenAddress;
            //path[0] = address(this);
            path[1] = pancakeswapV2Router.WETH();
    
            //token.gameApprove(address(this), address(pancakeswapV2Router), amount);
            token.approve(address(pancakeswapV2Router), amount);
            uint256 startingAmount = address(this).balance;
            
            // make the swap
            pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                0, // accept any amount of ETH
                path,
                //_tokenAddress,
                payable(address(this)),
                block.timestamp
            );
            return address(this).balance - startingAmount;
    }
    
    //send bnb amount
    function sendProfitsInBNB() private {
        for (uint i; i < numWinners; i++){
            payable(winners[i]).transfer(bnbProfits[i]);
        }
    }
    
    function dealWithLeftovers(uint leftovers) private {
        require(leftovers > 100, "no leftovers to spend");
        require(potRemaining > 100, "no leftovers to spend");
        uint nextRoundPot = 25; 
        uint liquidityAmount = 5; 
        uint marketingAddress = 10; 
        
        //There could potentially be some rounding error issues with this, but the sheer number of tokens
        //should keep any problems to a minium.
        // Fractions are set up as parts from the leftover 40%
        amountToSendToNextRound = (potRemaining * nextRoundPot);
        amountToSendToNextRound = amountToSendToNextRound.div(40);
        amountToSendToLiquidity = (potRemaining * liquidityAmount);
        amountToSendToLiquidity = amountToSendToLiquidity.div(40);
        amountToMarketingAddress = (potRemaining * marketingAddress);
        amountToMarketingAddress = amountToMarketingAddress.div(40);
    }
    
    //Send liquidity
    function swapAndAddLiqduidity() private {
        //sell half for bnb 
        uint halfOfLiqduidityAmount = amountToSendToLiquidity.div(2);

        //first swap half for BNB
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        //path[0] = payable(address(this));
        path[1] = pancakeswapV2Router.WETH();
        
        //approve pancakeswap to spend tokens
		token.approve(address(pancakeswapV2Router), halfOfLiqduidityAmount);

        //get the initial contract balance
        uint256 ethAmount = address(this).balance;
        
        //swap if there is money to Send
        if (amountToSendToLiquidity > 0) {
             pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                halfOfLiqduidityAmount,
                0, // accept any amount of BNB
                path,
                //_tokenAddress, //tokens get swapped to this contract so it has BNB to add liquidity
                payable(address(this)),
                block.timestamp + 30 seconds //30 second limit for the swap
                );
        
            ethAmount = address(this).balance - ethAmount;
        
            //now we have BNB, we can add liquidity to the pool
           token.approve(address(pancakeswapV2Router), halfOfLiqduidityAmount);
           
           pancakeswapV2Router.addLiquidityETH {value: ethAmount} (
                _tokenAddress, //token address
                halfOfLiqduidityAmount, //amount to send
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                liquidityTokenRecipient, // where to send the liqduity tokens
                block.timestamp + 30 seconds //deadline 
                );
        }
        
    }
    
    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
    
    function getRound() external view returns(uint){
        return roundNumber;
    }
    
    // ******************8 Sane functions for export to front end
    function totalPotValue() external view returns(uint){
        return potValue;
    }
    
    function getWinners() external view returns(address, address, address, address, address){
        return (winners[0], winners[1], winners[2], winners[3], winners[4]);
    }
    
    function getTicketsPerWinner() external view returns(uint, uint, uint, uint, uint)
    {
        //the ratio of payout is contingent on how many tickets that winner is holding vs the rest
        return (ticketBalance[winners[0]], ticketBalance[winners[1]], ticketBalance[winners[2]], ticketBalance[winners[3]], ticketBalance[winners[4]]);
    }
    
    function setTokenAddress(address newAddress) external {
        require(msg.sender == owner);
        _tokenAddress = newAddress;
        token = LSC(payable(_tokenAddress));
    }
    
    function getTokenAddress() external view returns(address) {
        return _tokenAddress;
    }
    
    function getEndTime() external view returns(uint){
        //Return the end time for the game in UNIX time
        return endTime;
    }
    
    function updatePancakeRouterInfo() external {
        require(msg.sender == owner);
        pancakeswapV2Router = token.pancakeswapV2Router(); // pulls router information directly from main contract
    }
    
    function setMarketingAddress(address _newAddress) external {
        require(msg.sender == owner);
        _marketingAddress = _newAddress;
    }
    
    function getMarketingAddress() external view returns(address) {
        return _marketingAddress;
    }
    
    function terminateGame() external {
        require(msg.sender == owner,  "Only the contract owner can terminate the game");
        terminator = true;
        endGame();
    }
}