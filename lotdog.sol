// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "github.com/gitdevstar/solidity_lib/Context.sol";
import "github.com/gitdevstar/solidity_lib/IBEP20.sol";
// import "github.com/gitdevstar/solidity_lib/Ownable.sol";
import "github.com/gitdevstar/solidity_lib/Address.sol";
import "github.com/gitdevstar/solidity_lib/SafeMath.sol";
import "github.com/gitdevstar/solidity_lib/IPancakeFactory.sol";
import "github.com/gitdevstar/solidity_lib/IPancakePair.sol";
import "github.com/gitdevstar/solidity_lib/IPancakeRouter02.sol";
import "github.com/gitdevstar/solidity_lib/SafeMathChainlink.sol";
import "github.com/gitdevstar/solidity_lib/EnumerableSet.sol";
import "github.com/gitdevstar/solidity_lib/VRFConsumerBase.sol";

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @dev Implementation of the {IBEP20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {BEP20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-BEP20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of BEP20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IBEP20-approve}.
 */
contract BEP20 is Context, IBEP20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {BEP20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IBEP20-balanceOf} and {IBEP20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IBEP20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IBEP20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IBEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IBEP20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IBEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IBEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IBEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IBEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

/**
 * @title The Owned contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract Owned {

    address public owner;
    address private pendingOwner;

    event OwnershipTransferRequested(
        address indexed from,
        address indexed to
    );
    event OwnershipTransferred(
        address indexed from,
        address indexed to
    );

    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Allows an owner to begin transferring ownership to a new address,
     * pending.
     */
    function transferOwnership(address _to)
    external
    onlyOwner()
    {
        pendingOwner = _to;

        emit OwnershipTransferRequested(owner, _to);
    }

    /**
     * @dev Allows an ownership transfer to be completed by the recipient.
     */
    function acceptOwnership()
    external
    {
        require(msg.sender == pendingOwner, "Must be proposed owner");

        address oldOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);

        emit OwnershipTransferred(oldOwner, msg.sender);
    }

    /**
     * @dev Reverts if called by anyone other than the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only callable by owner");
        _;
    }

}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a pBEPentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

abstract contract BEP677Receiver {
    function onTokenTransfer(address _sender, uint _value, bytes memory _data) public virtual;
}

/**
 * @notice This contract provides a one-to-one swap between pairs of tokens. It
 * is controlled by an owner who manages liquidity pools for all pairs. Most
 * users should only interact with the swap, onTokenTransfer, and
 * getSwappableAmount functions.
 */
contract PegSwap is Owned, ReentrancyGuard {
    using SafeMathChainlink for uint256;

    event LiquidityUpdated(
        uint256 amount,
        address indexed source,
        address indexed target
    );
    event TokensSwapped(
        uint256 amount,
        address indexed source,
        address indexed target,
        address indexed caller
    );
    event StuckTokensRecovered(
        uint256 amount,
        address indexed target
    );

    mapping(address => mapping(address => uint256)) private s_swappableAmount;

    /**
     * @dev Disallows direct send by setting a default function without the `payable` flag.
     */
    fallback()
    external
    {}

    /**
     * @notice deposits tokens from the target of a swap pair but does not return
     * any. WARNING: Liquidity added through this method is only retrievable by
     * the owner of the contract.
     * @param amount count of liquidity being added
     * @param source the token that can be swapped for what is being deposited
     * @param target the token that can is being deposited for swapping
     */
    function addLiquidity(
        uint256 amount,
        address source,
        address target
    )
    external
    {
        bool allowed = owner == msg.sender || _hasLiquidity(source, target);
        // By only allowing the owner to add a new pair, we reduce the potential of
        // possible attacks mounted by malicious token contracts.
        require(allowed, "only owner can add pairs");

        _addLiquidity(amount, source, target);

        require(BEP20(target).transferFrom(msg.sender, address(this), amount), "transferFrom failed");
    }

    /**
     * @notice withdraws tokens from the target of a swap pair.
     * @dev Only callable by owner
     * @param amount count of liquidity being removed
     * @param source the token that can be swapped for what is being removed
     * @param target the token that can is being withdrawn from swapping
     */
    function removeLiquidity(
        uint256 amount,
        address source,
        address target
    )
    external
    onlyOwner()
    {
        _removeLiquidity(amount, source, target);

        require(BEP20(target).transfer(msg.sender, amount), "transfer failed");
    }

    /**
     * @notice exchanges the source token for target token
     * @param amount count of tokens being swapped
     * @param source the token that is being given
     * @param target the token that is being taken
     */
    function swap(
        uint256 amount,
        address source,
        address target
    )
    external
    nonReentrant()
    {
        _removeLiquidity(amount, source, target);
        _addLiquidity(amount, target, source);

        emit TokensSwapped(amount, source, target, msg.sender);

        require(BEP20(source).transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        require(BEP20(target).transfer(msg.sender, amount), "transfer failed");
    }

    /**
     * @notice send funds that were accidentally transferred back to the owner. This
     * allows rescuing of funds, and poses no additional risk as the owner could
     * already withdraw any funds intended to be swapped. WARNING: If not called
     * correctly this method can throw off the swappable token balances, but that
     * can be recovered from by transferring the discrepancy back to the swap.
     * @dev Only callable by owner
     * @param amount count of tokens being moved
     * @param target the token that is being moved
     */
    function recoverStuckTokens(
        uint256 amount,
        address target
    )
    external
    onlyOwner()
    {
        emit StuckTokensRecovered(amount, target);

        require(BEP20(target).transfer(msg.sender, amount), "transfer failed");
    }

    /**
     * @notice swap tokens in one transaction if the sending token supports BEP677
     * @param sender address that initially initiated the call to the source token
     * @param amount count of tokens sent for the swap
     * @param targetData address of target token encoded as a bytes array
     */
    function onTokenTransfer(
        address sender,
        uint256 amount,
        bytes calldata targetData
    )
    external
    {
        address source = msg.sender;
        address target = abi.decode(targetData, (address));

        _removeLiquidity(amount, source, target);
        _addLiquidity(amount, target, source);

        emit TokensSwapped(amount, source, target, sender);

        require(BEP20(target).transfer(sender, amount), "transfer failed");
    }

    /**
     * @notice returns the amount of tokens for a pair that are available to swap
     * @param source the token that is being given
     * @param target the token that is being taken
     * @return amount count of tokens available to swap
     */
    function getSwappableAmount(
        address source,
        address target
    )
    public
    view
    returns(
        uint256 amount
    )
    {
        return s_swappableAmount[source][target];
    }


    // PRIVATE

    function _addLiquidity(
        uint256 amount,
        address source,
        address target
    )
    private
    {
        uint256 newAmount = getSwappableAmount(source, target).add(amount);
        s_swappableAmount[source][target] = newAmount;

        emit LiquidityUpdated(newAmount, source, target);
    }

    function _removeLiquidity(
        uint256 amount,
        address source,
        address target
    )
    private
    {
        uint256 newAmount = getSwappableAmount(source, target).sub(amount);
        s_swappableAmount[source][target] = newAmount;

        emit LiquidityUpdated(newAmount, source, target);
    }

    function _hasLiquidity(
        address source,
        address target
    )
    private
    returns (
        bool hasLiquidity
    )
    {
        if (getSwappableAmount(source, target) > 0) return true;
        if (getSwappableAmount(target, source) > 0) return true;
        return false;
    }

}

contract LSC is Context, IBEP20, Ownable, VRFConsumerBase {
    using SafeMathChainlink for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable WETH;

    bytes32 internal immutable keyHash;
    uint256 public linkFee;
    address public immutable linkAddress;
    address public immutable linkPegAddress;
    address public immutable pegSwapAddress;
    address public immutable linkPair;

    IPancakeRouter02 public immutable pancakeswapV2Router;
    PegSwap public immutable pegSwapContract;
    address public immutable pancakeswapV2Pair;
    IBEP20 public immutable linkPegContract;


    /*
    * Did the last winner receive his rewards. Being 'false' might indicate that
    * the transfer failed.
    */
    bool public lscWinnerPaid;

    /**
     * Random Number provided by ChainLink Oracle.
     * Used to determine winner of all eligible participants.
     */
    uint256 public lscRandomResult;

    /**
     * Address that has won the last lsc.
     */
    address payable public lscWinner;

    /**
     * Interval in which the lsc is conducted.
     * Used to determine lscNextTime.
     */
    uint256 public lscInterval = 8 hours;

    /**
     * When does the next lsc start?
     * Set during the last lsc.
     */
    uint256 public lscNextTime;

    /**
     * When was the last lsc conducted?
     */
    uint256 public lscLastTime;

    /**
     * Minimum amount of participants to do a lsc.
     * If current participants too small, then they are still eligible
     * to win in the next lsc without another buy.
     */
    uint8 public constant lscMinParticipants = 5;

    /**
    * Minimum to buy to participate in lsc in BNB.
    */
    uint256 public minlscEntryAmountBnb = (5 * 10**16); //0.05BNB

    /**
    * Threshold to determine whether to notify investors on huge buys/sells which enlarge the lsc pot significantly.
    */
    uint256 public lscThresholdHugeBuySell = (1 * 10**18); // Example: 50 BNB transfer 2% => 1 BNB

    /**
     * Amount of participant sets to save. Mainly used to
     * safely delete participant sets from previous lscs.
     * Needed because of solidity limitations to save gas.
     */
    uint8 private constant lscMaxParticipantSetIndex = 2;

    /**
    * Slippage for min entry price in BNB. 120 = 20 % slippage.
    */
    uint8 public tokenBnbEntryPriceSlippage = 120;

    /**
    * slippage for link buy
    * 100 = 1%
    * 50 = 2%
    * 25 = 4%
    */
    uint8 public swapLinkSlippageFactor = 25;

    /**
    * Initialize length of set with +1.
    */
    EnumerableSet.AddressSet[lscMaxParticipantSetIndex + 1]
        private lscParticipantSets;

    /**
     * Current index used for the participant set.
     * Determines which set of participants are eligible to win.
     * Will be incremented every x hours (and then starts at 0 again when greater than amount of overall sets).
     */
    uint8 public currentlscParticipantSetIndex = 0;

    /**
    * Factor to clean up participant sets.
    */
    uint8 public cleanUpFactor = 10;

    /**
     * Max uint8 constant to avoid throwing errors.
     * Used to determine if all lscSets have been cleared.
     */
    uint8 private constant MAX_INT8 = uint8(-1);

    address[] private _excluded;

    string private _name;
    string private _symbol;
    uint8 private _decimals = 9;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _totalSupply = 1 * 10**15 * 10**_decimals;
    uint256 private _rTotal = (MAX - (MAX % _totalSupply));
    uint256 private _tFeeTotal;



    /**
    * Bool to lock recursive calls to avoid interfering calls.
    */
    bool inSwapAndLiquify;

    /**
    * Enable/Disable liquidity swap functionality.
    */
    bool public swapAndLiquifyEnabled = true;

    /**
    * Enable/Disable lsc swap functionality.
    */
    bool public swapForlscEnabled = true;

    uint256 public _lotteryFee = 2;
    uint256 private _previousLotteryFee = _lotteryFee;

    uint256 public _taxFee = 4;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 4;
    uint256 private _previousLiquidityFee = _liquidityFee;

    /**
    * Token sum for adding to the LP pool
    */
    uint256 public _liquidityBalanceForPeriod = 0;

    /**
    * Winnable sum in next lsc in Tokens.
    * For winnable sum in BNB access address(this).balance
    */
    uint256 public _lotteryBalanceForPeriod = 0;

    /**
    * Amount the last winner has won in BNB.
    */
    uint256 public _lotteryBalanceInBNBForLastPeriod = 0;

    uint256 public _maxTxAmount = 1000000 * 10**6 * 10**9;
    uint256 private numTokensSellToAddToLiquidity = 500000 * 10**6 * 10**9;
    uint256 private numTokensSellForLottery = 500000 * 10**6 * 10**9;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;

    event lscWarning(string message);
    event WinnerPaid(address winnerAddress, uint256 amount);
    event WhaleAlert(uint256 generalAmount, uint256 addedToPot);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapForlsc(uint256 amount);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    // Structs sometimes needed as solidity only allows a certain number of function/return arguments.
    struct RValuesStruct {
        uint256 tAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tLottery;
        uint256 currentRate;
    }
    struct ValuesStruct {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 rLottery;
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tLottery;
    }

    constructor(
        string memory name,
        string memory symbol,
        address routerAddress,
        address vrfCoordinator,
        address link,
        address linkPeg,
        address pegSwap,
        bytes32 _keyHash
    )
        public
        VRFConsumerBase(vrfCoordinator, link)
    {
        linkAddress = link;
        linkPegAddress = linkPeg;
        pegSwapAddress = pegSwap;
        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(routerAddress);
        pegSwapContract = PegSwap(pegSwap);
        linkPegContract = IBEP20(linkPeg);
        WETH = _pancakeswapV2Router.WETH();

        linkPair = IPancakeFactory(_pancakeswapV2Router.factory())
            .getPair(linkPeg, _pancakeswapV2Router.WETH());

        // Set initial lsc time.
        lscNextTime = block.timestamp + lscInterval;

        keyHash = _keyHash;
        linkFee = 2 * 10**17; // 0.2 LINK for BSC Prod (Varies by network)

        _name = name;
        _symbol = symbol;

        _rOwned[_msgSender()] = _rTotal;

        // Create a Pancake pair for this new token
        pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
            .createPair(address(this), _pancakeswapV2Router.WETH());

        // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    /**
     * Verify lsc eligibility + Add / Remove address from lsc participants
     */
    function _modifylscEligibility(
        address from,
        address to,
        uint256 amount,
        bool takeFee
    ) private {
        if(takeFee && swapForlscEnabled){

            uint256 amountTokenBnbPrice = getBnbPriceOfToken(pancakeswapV2Pair, amount);
            uint256 amountTokenBnbPriceWithSlippage = amountTokenBnbPrice.mul(tokenBnbEntryPriceSlippage).div(100); // 20 % slippage

            if (from == pancakeswapV2Pair && amountTokenBnbPriceWithSlippage >= minlscEntryAmountBnb) {
                //verify BUY, then add to current participant list
                addlscParticipant(to);
            } else if (to == pancakeswapV2Pair) {
                //verify SELL, then remove from current participant list (if already added)
                removelscParticipant(from);
            }

            startNextlscIfExpired();
        }
    }

    /**
     * @dev Remember that only owner can call so be careful when use on contracts generated from other contracts.
     * @param tokenAddress The token contract address
     * @param tokenAmount Number of tokens to be sent
     source: https://github.com/vittominacori/eth-token-recover/blob/master/contracts/TokenRecover.sol
     */
    function recoverBEP20(address tokenAddress, uint256 tokenAmount) external onlyOwner() {
        IBEP20(tokenAddress).transfer(owner(), tokenAmount);
    }

    // Called on every transaction if takeFee && swapForlscEnabled
    function startNextlscIfExpired() private {
        if (block.timestamp >= lscNextTime) {
            scheduleNextlsc();
            // Only do lsc if at least n address bought min amount
            if (
                lscParticipantSets[currentlscParticipantSetIndex]
                    .length() >= lscMinParticipants
            ) {
                bool linkExchanged = swapBnbForLink();
                if (linkExchanged) {
                    // Link needed, if no Link there then simply don't do a lsc.
                    bool lscInitiated = startlscProcedure(block.number);
                    if(!lscInitiated) {
                        emit lscWarning("Not enough LINK on contract balance");
                    }
                } else {
                    emit lscWarning("Not enough BNB for BNB->LINK swap");
                }
            } else {
                emit lscWarning("Not enough participants to start lsc.");
            }
        } else {
            _cleanUpPreviousParticipantSets();
        }
    }

    /**
     * swap BNB -> PegLINK via pancakeswap
     * swap PegLINK -> Link via PegSwap
     * @return true if success
     * false if failed duo to low Bnb balance
     */
    function swapBnbForLink() private
    returns (bool)
    {
        uint256 linkFeePrice = getTokenPriceInBnb(linkPair, linkFee);

        //1 = can't find the LP pair
        if(linkFeePrice == 1){
            emit lscWarning("Can't find Link LP Pair");
            return false;
        }

        uint256 linkFeePriceWithSlippage = linkFeePrice.add(linkFeePrice.div(swapLinkSlippageFactor)); // 1% bc. of fees

        if(linkFeePriceWithSlippage < address(this).balance) {
            address[] memory path = new address[](2);
            path[0] = pancakeswapV2Router.WETH();
            path[1] = address(linkPegAddress);

            // make the swap
            pancakeswapV2Router.swapETHForExactTokens{value: linkFeePriceWithSlippage }(
                linkFee,
                path,
                address(this),
                block.timestamp
            );

            // aprove pe pegSwapToeken to pegSwap
            linkPegContract.approve(address(pegSwapAddress), linkFee);

            // Now swap Pegged LINK to actual LINK. Thank you Link marines <3
            pegSwapContract.swap(linkFee, linkPegAddress, linkAddress);

            return true;
        } else {
            return false;
        }
    }

    //Get current price info of LP Pair
    // Input: Bnb amount
    // Output: token amount
    function getBnbPriceOfToken(address pairAddress, uint amount) private view returns(uint)
    {
        if(isContract(pairAddress)){
            IPancakePair pair = IPancakePair(pairAddress);
            (uint Res0, uint Res1,) = pair.getReserves();
            return (amount * Res1) / Res0;
        } else {
            return 1;
        }
    }

    //Get current price info of LP Pair
    // Input: token amount
    // Output: Bnb amount
    function getTokenPriceInBnb(address pairAddress, uint amount) private view returns(uint)
    {
        if(isContract(pairAddress)){
            IPancakePair pair = IPancakePair(pairAddress);
            (uint Res0, uint Res1,) = pair.getReserves();
            return (amount * Res0) / Res1;
        } else {
            return 1;
        }
    }

    /**
    * Evaluates whether address is a contract and exists.
    */
    function isContract(address addr) view private returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    /**
     * Start startlscProcedure -> requests randomness from the Link Oracle
     */
    function startlscProcedure(uint256 userProvidedSeed)
        private
        returns (bool)
    {
        if(LINK.balanceOf(address(this)) >= linkFee) {
            requestRandomness(keyHash, linkFee, userProvidedSeed);
            return true;
        } else {
            return false;
        }
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        lscRandomResult = randomness;
        payWinner();
        nextlscParticipantSet();
    }

    function payWinner() private {
        uint256 length =
            lscParticipantSets[currentlscParticipantSetIndex].length();

        // Determine winner (randomResult from ChainLink oracle)
        uint256 winnerIdx = lscRandomResult.mod(length);
        lscWinner = payable(lscParticipantSets[currentlscParticipantSetIndex]
            .at(winnerIdx));

        // Actually pay winner
        _lotteryBalanceInBNBForLastPeriod = address(this).balance; // will be more than previous _lotteryBalanceForPeriod bc. of BNB bug from SafeMoon
        _lotteryBalanceForPeriod = 0; // reset winnable sum

        lscWinnerPaid = lscWinner.send(_lotteryBalanceInBNBForLastPeriod);
        if (lscWinnerPaid) {
            emit WinnerPaid(lscWinner, _lotteryBalanceInBNBForLastPeriod);
        } else {
            emit lscWarning("Couldn't pay winner. Send transaction failed.");
        }
    }

    /**
     * Schedule next lsc by setting the time.
     */
    function scheduleNextlsc() private {
        lscLastTime = lscNextTime; // set last lsc time
        lscNextTime = lscLastTime + lscInterval;
    }

    /**
     * Clean up previous participants set. Private call
     */
    function _cleanUpPreviousParticipantSets() private {
        uint8 nextNonEmptySetIndex = getNextNonEmptyParticipantSet();
        if (nextNonEmptySetIndex != MAX_INT8) { // MAX_INT8 -> all sets empty (except current one)
            garbageCollectlscParticipants(nextNonEmptySetIndex, cleanUpFactor);
        } // otherwise no non-empty set except current one.
    }

    /**
     * Clean up previous participants set.
     * Duplicated method to be able to manually clear previous participants to ensure fair lscs if needed.
     */
    function cleanUpPreviousParticipantSets() public onlyOwner() {
        _cleanUpPreviousParticipantSets();
    }

    /**
     * Get next expired participant set which is not empty (needs to be cleared.)
     */
    function getNextNonEmptyParticipantSet() private view returns (uint8) {
        uint8 nextNonEmptySetIndex =
            getNextlscParticipantSet(currentlscParticipantSetIndex);
        uint256 countParticipants;

        while (nextNonEmptySetIndex != currentlscParticipantSetIndex) {
            countParticipants = lscParticipantSets[nextNonEmptySetIndex]
                .length();
            if (countParticipants > 0) {
                return nextNonEmptySetIndex;
            } else {
                // Ensure while condition doesn't loop forever
                nextNonEmptySetIndex = getNextlscParticipantSet(
                    nextNonEmptySetIndex
                );
            }
        }
        return MAX_INT8; // all sets empty (except current one)
    }

    /**
     * Get's the next set of participants.
     */
    function getNextlscParticipantSet(uint8 startFromIndex) private pure returns (uint8)
    {
        uint8 nextlscParticipantSetIndex;
        if (startFromIndex >= lscMaxParticipantSetIndex) {
            nextlscParticipantSetIndex = 0;
        } else {
            nextlscParticipantSetIndex = startFromIndex + 1;
        }
        return nextlscParticipantSetIndex;
    }

    /**
     * Switches to next lsc participants set.
     */
    function nextlscParticipantSet() private returns (uint8) {
        currentlscParticipantSetIndex = getNextlscParticipantSet(
            currentlscParticipantSetIndex
        );
        return currentlscParticipantSetIndex;
    }

    function addlscParticipant(address wallet) private returns (bool) {
        return
            lscParticipantSets[currentlscParticipantSetIndex].add(wallet);
    }

    function removelscParticipant(address wallet) private returns (bool) {
        return
            lscParticipantSets[currentlscParticipantSetIndex].remove(
                wallet
            );
    }

    /**
    * Does an address participate in the next lsc?
    * @return Bool whether address participates.
    */
    function containslscParticipant(address wallet)
        public
        view
        returns (bool)
    {
        return lscParticipantSets[currentlscParticipantSetIndex].contains(wallet);
    }

    /**
    * Clears previous lsc participant sets.
    * @return Did clean up succeed? Returns false if someone tried to clear current set.
    */
    function garbageCollectlscParticipants(uint8 setIndex, uint256 count)
        private
        returns (bool)
    {
        if (setIndex != currentlscParticipantSetIndex) {
            return lscParticipantSets[setIndex].clean(count);
        }
        return false;
    }

    /**
    * Amount of participants in next lsc.
    * @return Length of current participant set.
    */
    function lengthlscParticipants() public view returns (uint256) {
        return lscParticipantSets[currentlscParticipantSetIndex].length();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount /*, "BEP20: transfer amount exceeds allowance"*/
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue /*, "BEP20: decreased allowance below zero"*/
            )
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        uint256 rAmount = _getValues(tAmount).rAmount;

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _totalSupply, "Amount must be less than supply");
        if (!deductTransferFee) {
            return _getValues(tAmount).rAmount;
        } else {
            return _getValues(tAmount).rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Pancake router.');
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        ValuesStruct memory valuesStruct = _getValues(tAmount);
        uint256 rAmount = valuesStruct.rAmount;
        uint256 rTransferAmount = valuesStruct.rTransferAmount;
        uint256 rFee = valuesStruct.rFee;
        uint256 tTransferAmount = valuesStruct.tTransferAmount;
        uint256 tFee = valuesStruct.tFee;
        uint256 tLiquidity = valuesStruct.tLiquidity;
        uint256 tLottery = valuesStruct.tLottery;


        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeForlsc(tLottery);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxFeePBEPent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }

    /**
    * Slippage for min entry price in BNB. 120 = 20 % slippage.
    */
    function setTokenBnbEntryPriceSlippage(uint8 _tokenBnbEntryPriceSlippage) external onlyOwner() {
        tokenBnbEntryPriceSlippage = _tokenBnbEntryPriceSlippage;
    }



    function setNumTokensSellToAddToLiquidity(uint256 _numTokensSellToAddToLiquidity) external onlyOwner() {
        numTokensSellToAddToLiquidity = _numTokensSellToAddToLiquidity;
    }

    function setNumTokensSellForLottery(uint256 _numTokensSellForLottery) external onlyOwner() {
        numTokensSellForLottery = _numTokensSellForLottery;
    }

    function setMinlscEntryAmount(uint256 _minlscEntryAmount) external onlyOwner() {
        minlscEntryAmountBnb = _minlscEntryAmount;
    }

    function setLotteryFeePBEPent(uint256 lotteryFee) external onlyOwner() {
        _lotteryFee = lotteryFee;
    }

    function setlscNextTime(uint256 _lscNextTime) external onlyOwner() {
        lscNextTime = _lscNextTime;
    }

    function setlscThresholdHugeBuySell(uint256 _lscThresholdHugeBuySell) external onlyOwner() {
        lscThresholdHugeBuySell = _lscThresholdHugeBuySell;
    }

    function setLiquidityFeePBEPent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }


    function setLinkFee(uint256 _linkFee) external onlyOwner() {
        linkFee = _linkFee;
    }

    function setMaxTxPBEPent(uint256 maxTxPBEPent) external onlyOwner() {
        _maxTxAmount = _totalSupply.mul(maxTxPBEPent).div(10**2);
    }

    function setSwapLinkSlippageFactor(uint8 _swapLinkSlippageFactor) external onlyOwner() {
        swapLinkSlippageFactor = _swapLinkSlippageFactor;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setSwapForlscEnabled(bool _enabled) public onlyOwner {
        swapForlscEnabled = _enabled;
    }

    function setlscInterval(uint256 _lscInterval) public onlyOwner {
        lscInterval = _lscInterval;
    }

    function setCleanUpFactor(uint8 _cleanUpFactor) public onlyOwner {
        cleanUpFactor = _cleanUpFactor;
    }


    // to recieve ETH from pancakeswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (ValuesStruct memory)
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tLottery) =
            _getTValues(tAmount);

        RValuesStruct memory rValuesStruct = RValuesStruct(tAmount, tFee, tLiquidity, tLottery, _getRate());
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rLottery) =
            _getRValues(rValuesStruct);

        return ValuesStruct(
            rAmount,
            rTransferAmount,
            rFee,
            rLottery,
            tTransferAmount,
            tFee,
            tLiquidity,
            tLottery
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tLottery = calculateLotteryFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(tLottery);
        return (tTransferAmount, tFee, tLiquidity, tLottery);
    }

    function _getRValues(
       RValuesStruct memory rValuesStruct
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = rValuesStruct.tAmount.mul(rValuesStruct.currentRate);
        uint256 rFee = rValuesStruct.tFee.mul(rValuesStruct.currentRate);
        uint256 rLiquidity = rValuesStruct.tLiquidity.mul(rValuesStruct.currentRate);
        uint256 rLottery = rValuesStruct.tLottery.mul(rValuesStruct.currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee, rLottery);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _totalSupply;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _totalSupply);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_totalSupply)) return (_rTotal, _totalSupply);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        _liquidityBalanceForPeriod = _liquidityBalanceForPeriod + tLiquidity; // Save liquidity to overall balance until next lsc.
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _takeForlsc(uint tLottery) private {
        _lotteryBalanceForPeriod = _lotteryBalanceForPeriod + tLottery; // Save lottery to overall balance until next lsc.

        if (swapForlscEnabled && _lotteryFee != 0 && tLottery != 0) {
            uint256 tLotteryInBnb = getTokenPriceInBnb(pancakeswapV2Pair, tLottery);
            if (tLotteryInBnb > lscThresholdHugeBuySell) {
                // Send event to notify investors about huge lscs, when someone sold/bought a huge amount.
                emit WhaleAlert(getTokenPriceInBnb(pancakeswapV2Pair, _lotteryBalanceForPeriod), tLotteryInBnb);
            }
        }

        uint256 currentRate = _getRate();
        uint256 rLottery = tLottery.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLottery);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tLottery);
        }
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**2);
    }

    function calculateLotteryFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_lotteryFee).div(10**2);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0 && _lotteryFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousLotteryFee = _lotteryFee;

        _taxFee = 0;
        _liquidityFee = 0;
        _lotteryFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _lotteryFee = _previousLotteryFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (
            (from != owner() && to != owner()) &&
            (!_isExcludedFromFee[from] && !_isExcludedFromFee[to])
        )
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is Pancake pair.
        uint256 contractTokenBalance = balanceOf(address(this));


        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        bool LiquidityOverMinTokenBalance = _liquidityBalanceForPeriod >= numTokensSellToAddToLiquidity;
        bool LotteryOverMinTokenBalance = _lotteryBalanceForPeriod >= numTokensSellForLottery;
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

    if (
            LiquidityOverMinTokenBalance &&
            !inSwapAndLiquify &&
            from != pancakeswapV2Pair && //Non buy tx (sell or transfer)
            swapAndLiquifyEnabled &&
            takeFee

        ) {
            //add liquidity
            swapAndLiquify(numTokensSellToAddToLiquidity);

            // LiquidityBalance always larger because of outer if condition
            _liquidityBalanceForPeriod = _liquidityBalanceForPeriod.sub(numTokensSellToAddToLiquidity);

        } else if (
            LotteryOverMinTokenBalance &&
            !inSwapAndLiquify &&
            from != pancakeswapV2Pair && //Non buy tx (sell or transfer)
            swapForlscEnabled &&
            takeFee
        ) {
            // add to lsc pot
            _swapForlsc(numTokensSellForLottery);
            _lotteryBalanceForPeriod = _lotteryBalanceForPeriod.sub(numTokensSellForLottery);
        }

        _modifylscEligibility(from, to, amount, takeFee);

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2); //ETH
        uint256 otherHalf = contractTokenBalance.sub(half); //BNB

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to Pancake
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _swapForlsc(uint256 amount) private lockTheSwap {
        swapTokensForEth(amount);
        emit SwapForlsc(amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the Pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH();

        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // make the swap
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        ValuesStruct memory valuesStruct = _getValues(tAmount);
        uint256 rAmount = valuesStruct.rAmount;
        uint256 rTransferAmount = valuesStruct.rTransferAmount;
        uint256 rFee = valuesStruct.rFee;
        // uint256 rLottery = valuesStruct.rLottery;
        uint256 tTransferAmount = valuesStruct.tTransferAmount;
        uint256 tFee = valuesStruct.tFee;
        uint256 tLiquidity = valuesStruct.tLiquidity;
        uint256 tLottery = valuesStruct.tLottery;

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeForlsc(tLottery);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        ValuesStruct memory valuesStruct = _getValues(tAmount);
        uint256 rAmount = valuesStruct.rAmount;
        uint256 rTransferAmount = valuesStruct.rTransferAmount;
        uint256 rFee = valuesStruct.rFee;
        // uint256 rLottery = valuesStruct.rLottery;
        uint256 tTransferAmount = valuesStruct.tTransferAmount;
        uint256 tFee = valuesStruct.tFee;
        uint256 tLiquidity = valuesStruct.tLiquidity;
        uint256 tLottery = valuesStruct.tLottery;

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeForlsc(tLottery);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        ValuesStruct memory valuesStruct = _getValues(tAmount);
        uint256 rAmount = valuesStruct.rAmount;
        uint256 rTransferAmount = valuesStruct.rTransferAmount;
        uint256 rFee = valuesStruct.rFee;
        // uint256 rLottery = valuesStruct.rLottery;
        uint256 tTransferAmount = valuesStruct.tTransferAmount;
        uint256 tFee = valuesStruct.tFee;
        uint256 tLiquidity = valuesStruct.tLiquidity;
        uint256 tLottery = valuesStruct.tLottery;

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeForlsc(tLottery);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}