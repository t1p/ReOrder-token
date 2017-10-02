pragma solidity ^0.4.13;

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) constant returns (uint256);
    function transfer(address to, uint256 value) returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) returns (bool);
    function approve(address spender, uint256 value) returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
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

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {

    using SafeMath for uint256;

    mapping(address => uint256) balances;

    // Fix for the ERC20 short address attack
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

}

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

    mapping (address => mapping (address => uint256)) allowed;

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amout of tokens to be transfered
     */
    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) returns (bool) {
        var _allowance = allowed[_from][msg.sender];

        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // require (_value <= _allowance);

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) onlyPayloadSize(2 * 32) returns (bool) {

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifing the amount of tokens still available for the spender.
     */
    function allowance(address _owner, address _spender) onlyPayloadSize(2 * 32) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}

contract owned {

    address public owner;
    address public newOwner;

    function owned() payable {
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

/**
 * @title Mintable token
 * @dev Simple ERC20 Token example, with mintable token creation
 * @dev Issue: * https://github.com/OpenZeppelin/zeppelin-solidity/issues/120
 * Based on code by TokenMarketNet: https://github.com/TokenMarketNet/ico/blob/master/contracts/MintableToken.sol
 */
contract MintableToken is StandardToken, owned {

    event Mint(address indexed to, uint256 amount);

    event MintFinished();

    bool public mintingFinished = false;

    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    /**
     * @dev Function to mint tokens
     * @param _to The address that will recieve the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address _to, uint256 _amount) onlyOwner canMint onlyPayloadSize(2 * 32) returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
        return true;
    }

    /**
     * @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() onlyOwner returns (bool) {
        mintingFinished = true;
        MintFinished();
        return true;
    }

}

contract SimpleTokenCoin is MintableToken {

    string public constant name = "Coin Token";

    string public constant symbol = "R";

    uint32 public constant decimals = 8;
}

contract CrowdsalePhase is owned {

    using SafeMath for uint256;

    uint public number;
    uint256 public leftAmount;
    uint256 public givenTokens = 0;
    uint public start;
    uint public period;
    uint public discount;
    uint public rate;
    bool public refundable;
    uint end = 0;

    modifier saleIsStared() {
        require(now >= start);
        _;
    }

    function getEndTime() public constant returns (uint){
        if (end != 0) {
            return end;
        }
        uint endTime = start + period;
        if (endTime > now) {
            end = endTime;
        }
        return endTime;
    }

    function timeIsOver() public constant returns (bool) {
        return now < start || now > start + period;
    }

    function saleIsOver() public constant returns (bool) {
        return leftAmount == 0 || timeIsOver();
    }

    function CrowdsalePhase(
    uint phaseNumber,
    uint phaseAmount,
    uint phaseStart,
    uint phasePeriodInDays,
    uint phaseDiscountInPercent,
    uint phaseRate,
    bool phaseRefundable) public
    {
        number = phaseNumber;
        leftAmount = phaseAmount;
        start = phaseStart;
        period = phasePeriodInDays;
        discount = phaseDiscountInPercent;
        rate = phaseRate;
        refundable = phaseRefundable;
    }

    function countTokens(uint256 orderingValue)
    public saleIsStared onlyOwner
    returns (uint256 overAmount, uint256 givenTokens, bool phaseOver)
    {
        if (saleIsOver()) {
            return (orderingValue, 0, true);
        }
        uint256 value = orderingValue;
        if (orderingValue >= leftAmount) {
            value = leftAmount;
            end = now;
        }
        uint256 tokens = value.mul(rate).mul(100).div((100 - discount)).div(1 ether);
        givenTokens = givenTokens.add(tokens);
        leftAmount = leftAmount.sub(value);
        return (orderingValue - value, tokens, leftAmount == 0);
    }
}

/**
 * @title Crowdsale
 * @dev Implementation for 4 phases crowdsale.
*/
contract Crowdsale is owned {

    using SafeMath for uint256;

    /**
     * @dev type of crowdsale state.
    */
    enum CrowdsaleState {Opened, Closed, Failed}

    uint256 totalSupply;
    uint startTime;
    uint endTime;
    CrowdsaleState state;
    mapping (address => uint256) amounts;
    uint256 totalAmount;

    uint256 constant rate = 300 * 100000000;

    SimpleTokenCoin public token = new SimpleTokenCoin();

    CrowdsalePhase phase;

    function Crowdsale() public {
        uint crowdsaleStart = now + 1;
        require(now < crowdsaleStart);
        startTime = crowdsaleStart;
        // Create the first phase with number 1, 50 ether amount, start time, 2 days, 30 percent discount, constant rate, refundable
        phase = new CrowdsalePhase(1, 50 ether, crowdsaleStart, 2 days, 30, rate, true);
        state = CrowdsaleState.Opened;
    }

    function isFailed() returns (bool) {
        if (phase.refundable() && (phase.leftAmount() != 0) && phase.timeIsOver()) {
            endTime = now;
            state = CrowdsaleState.Failed;
            return true;
        }
        return false;
    }

    function isClosed() returns (bool) {
        if (phase.number() == 4 && phase.saleIsOver()) {
            endTime = now;
            state = CrowdsaleState.Closed;
            return true;
        }
        return false;
    }

    function nextActivePhase() {
        uint phaseEnd = phase.getEndTime();
        if (phase.number() == 1 && !isFailed()) {
            // Create second phase with number 2, 50 ether amount, start time (end previous phase), 2 days, 30 percent discount, constant rate, not refundable
            phase = new CrowdsalePhase(2, 50 ether, phaseEnd, 2 days, 30, rate, false);
        } else if (phase.number() == 2) {
            // Create second phase with number 3, 50 ether amount, start time (end previous phase), 2 days, 20 percent discount, constant rate, not refundable
            phase = new CrowdsalePhase(3, 50 ether, phaseEnd, 2 days, 20, rate, false);
        } else if (phase.number() == 3) {
            // Create second phase with number 4, 50 ether amount, start time (end previous phase), 2 days, 10 percent discount, constant rate, not refundable
            phase = new CrowdsalePhase(4, 50 ether, phaseEnd, 2 days, 10, rate, false);
        } else if (phase.number() == 4) {
            endTime = phaseEnd;
            state = CrowdsaleState.Closed;
        }
    }

    function() external payable {
        uint256 tokens = 0;
        uint256 leftValue = msg.value;
        while (state == CrowdsaleState.Opened && leftValue > 0){
            var (overAmount, givenTokens, phaseOver) = phase.countTokens(leftValue);
            tokens = tokens.add(givenTokens);
            leftValue = overAmount;
            if (phaseOver) {
                nextActivePhase();
            }
        }
        uint256 amount = msg.value.sub(leftValue);
        require(amount > 0);
        amounts[msg.sender] = amount.add(amounts[msg.sender]);
        if (leftValue != 0) {
            require(msg.sender.call.gas(3000000).value(leftValue)());
        }
        totalAmount = totalAmount.add(amount);
        totalSupply = totalSupply.add(tokens);
        token.mint(msg.sender, tokens);
    }

    function refund() external {
        if (isFailed()) {
            uint256 amount = amounts[msg.sender];
            require(amount > 0);
            token.transfer(this, token.balanceOf(msg.sender));
            require(msg.sender.call.gas(3000000).value(amount)());
        }
    }

    function withdraw() external onlyOwner {
        if (isClosed()) {
            require(msg.sender.call.gas(3000000).value(totalAmount)());
        }
    }
}
