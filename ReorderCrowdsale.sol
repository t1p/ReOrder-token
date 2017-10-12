pragma solidity ^0.4.16;


contract ERC20Basic {
    uint256 public totalSupply;

    function balanceOf(address who) constant public returns (uint256);

    function transfer(address to, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}


contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant public returns (uint256);

    function transferFrom(address from, address to, uint256 value) public returns (bool);

    function approve(address spender, uint256 value) public returns (bool);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}


library SafeMath {

    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

}


contract BasicToken is ERC20Basic {

    using SafeMath for uint256;

    mapping (address => uint256) balances;

    // Fix for the ERC20 short address attack
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

}


contract StandardToken is ERC20, BasicToken {

    mapping (address => mapping (address => uint256)) allowed;

    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) public returns (bool) {
        var _allowance = allowed[_from][msg.sender];

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool) {

        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) onlyPayloadSize(2 * 32) constant public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}


contract owned {

    address public owner;

    address public newOwner;

    function owned() public payable {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    function changeOwner(address _owner) onlyOwner public {
        require(_owner != 0);
        newOwner = _owner;
    }

    function confirmOwner() public {
        require(newOwner == msg.sender);
        owner = newOwner;
        delete newOwner;
    }
}


contract MintableToken is StandardToken, owned {

    event Mint(address indexed to, uint256 amount);

    event MintFinished();

    bool public mintingFinished = false;

    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    function mint(address _to, uint256 _amount) onlyOwner canMint onlyPayloadSize(2 * 32) public returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
        return true;
    }

    function finishMinting() onlyOwner public returns (bool) {
        mintingFinished = true;
        MintFinished();
        return true;
    }

}


contract RCoin is MintableToken {

    string public constant name = "R Coin";

    string public constant symbol = "R";

    uint32 public constant decimals = 18;
}


/**
 * @title Crowdsale
 * @dev Implementation for 3 phases crowdsale.
*/
contract Crowdsale is owned {

    using SafeMath for uint256;

    RCoin token;

    uint256 constant tokenDecimals = 1000000000000000000;

    uint256 public totalSupply = 0;
    uint256 public totalAmount = 0;
    uint256 public currentAmount = 0;

    uint256 public constant minCrowdsaleAmount =    35000 * tokenDecimals; // min amount for successfull crowdsale
    uint256 public constant maxAmount =             35000000 * tokenDecimals; // max minting amount
    uint256 public constant developmentFundAmount = 3500000 * tokenDecimals; // amount of development fund
    uint256 public constant teamAmount =            1750000 * tokenDecimals; // amount for team
    uint256 public constant bountyAmount =          1750000 * tokenDecimals; // bounty amount
    uint256 public constant bonusesTimeFrozen = 90 days; // freeze time for get all bonuses
    bool public bonusesPayed = false;

    uint256 public constant rateToEther = 100; // rate to ether, how much tokens gives to 1 ether

    uint public constant presaleDiscount =      40;
    uint public constant firstPhaseDiscount =   30;
    uint public constant secondPhaseDiscount =  20;
    uint public constant thirdPhaseDiscount =   10;
    uint256 public constant maxPresaleAmount =      1500000 * tokenDecimals;
    uint256 public constant maxFirstPhaseAmount =   4500000 * tokenDecimals;
    uint256 public constant maxSecondPhaseAmount =  15000000 * tokenDecimals;
    uint256 public constant maxThirdPhaseAmount =   28000000 * tokenDecimals;

    uint256 public constant minPresaleAmountForDeal = 10 * 1000000000000000000;

    mapping (address => uint256) amounts;

    uint public constant startTime =    1510056000; // start at 07 NOV 2017 07:00:00 EST
    uint public constant endTime =      1512648000; // end at   07 DEC 2017 07:00:00 EST

    modifier canBuy() {
        require(!isFinished());
        if (now < startTime) {
            require(msg.value >= minPresaleAmountForDeal && totalSupply < maxPresaleAmount);
        } else {
            require(totalSupply < maxThirdPhaseAmount);
        }
        _;
    }

    modifier canRefund() {
        require(isFinished() && totalSupply < minCrowdsaleAmount);
        _;
    }

    modifier canReward() {
        require(totalSupply >= minCrowdsaleAmount);
        _;
    }

    function Crowdsale() public {
        require(now < startTime);
        token = new RCoin();
    }

    function isFinished() public constant returns (bool) {
        return now > endTime || totalSupply >= maxThirdPhaseAmount;
    }

    function isSuccess() public constant returns (bool) {
        return totalSupply >= minCrowdsaleAmount;
    }

    function() external canBuy payable {
        uint discount = getDiscount();
        uint256 amount = msg.value;
        uint256 givenTokens = amount.mul(rateToEther).mul(100).div(100 - discount);
        uint256 leftTokens = maxThirdPhaseAmount.sub(totalSupply);

        if (givenTokens > leftTokens) {
            givenTokens = givenTokens.sub(leftTokens);
            uint256 needAmount = givenTokens.mul(100 - discount).div(rateToEther).div(100);
            require(amount > needAmount);
            require(msg.sender.call.gas(3000000).value(amount.sub(needAmount))());
            amount = needAmount;
        }

        // If success we don't need information about amounts for refunding.
        if (!isSuccess()) {
            amounts[msg.sender] = amount.add(amounts[msg.sender]);
        }

        totalAmount = totalAmount.add(amount);
        currentAmount = currentAmount.add(amount);

        totalSupply = totalSupply.add(givenTokens);
        token.mint(msg.sender, givenTokens);
    }

    function getDiscount() private returns (uint) {
        if (now < startTime) {
            return presaleDiscount;
        } else if (totalSupply > maxSecondPhaseAmount) {
            return thirdPhaseDiscount;
        } else if (totalSupply > maxFirstPhaseAmount) {
            return secondPhaseDiscount;
        }
        return firstPhaseDiscount;
    }

    function finishCrowdsale() external onlyOwner {
        require(isFinished() && isSuccess() && !bonusesPayed);
        uint256 bonuses = developmentFundAmount.add(teamAmount).add(bountyAmount);
        token.mint(this, bonuses);
        bonusesPayed = true;
        // after this action token will not be able to mint any more
        token.finishMinting();
    }

    function receiveFrozenBonuses() external onlyOwner {
        require(bonusesPayed);
        require(now > endTime + bonusesTimeFrozen);
        uint256 bonuses = developmentFundAmount.add(teamAmount).add(bountyAmount);
        token.transfer(msg.sender, bonuses);
    }

//    function migrateToken(address newContract) external onlyOwner {
//        require(isFinished());
//        token.changeOwner(newContract);
//    }

    function refund() external canRefund {
        uint256 amount = amounts[msg.sender];
        require(amount > 0);
        token.transfer(this, token.balanceOf(msg.sender));
        require(msg.sender.call.gas(3000000).value(amount)());
    }

    function withdraw() external onlyOwner canReward {
        require(msg.sender.call.gas(3000000).value(currentAmount)());
        currentAmount = 0;
    }

    function withdrawAmount(uint256 amount) external onlyOwner canReward {
        require(msg.sender.call.gas(3000000).value(amount)());
        if (currentAmount > amount) {
            currentAmount = currentAmount.sub(amount);
        } else {
            currentAmount = 0;
        }
    }
}
