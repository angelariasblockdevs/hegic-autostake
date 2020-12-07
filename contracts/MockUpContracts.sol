// // SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.5;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


contract FakeHegicToken is Ownable, ERC20("Fake HEGIC", "FakeHEGIC") {
    constructor() {
        _mint(msg.sender, 100e18);
    }

    function mint(uint amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function getTokenName() external pure returns (string memory) {
        return "Fake HEGIC";
    }
}


contract FakeRHegicToken is Ownable, ERC20("Fake rHEGIC", "FakeRHEGIC") {
    constructor() {
        _mint(msg.sender, 100e18);
    }

    function mint(uint amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function getTokenName() external pure returns (string memory) {
        return "Fake rHEGIC";
    }
}


contract IOUTokenRedemption is Ownable {
    using SafeMath for uint;
    using SafeERC20 for ERC20;

    struct Deposit {
        uint blockDeposited;
        uint amountDeposited;
        uint amountRedeemed;
    }

    uint public immutable blocksToRelease;  // How many block since since deposit will HEGIC be completely released.
    mapping(address => Deposit) public deposits;

    ERC20 public immutable inputToken;
    ERC20 public immutable outputToken;

    constructor(ERC20 _inputToken, ERC20 _outputToken, uint _blocksToRelease) {
        inputToken = _inputToken;
        outputToken = _outputToken;
        blocksToRelease = _blocksToRelease;
    }

    function fundOutputToken(uint amount) external onlyOwner {
        outputToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function deposit(uint amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(deposits[msg.sender].amountDeposited == 0, "This account has already deposited");

        deposits[msg.sender] = Deposit({
            blockDeposited: block.number,
            amountDeposited: amount,
            amountRedeemed: 0
        });

        inputToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function redeem() external returns (uint amount) {
        amount = getRedeemableAmount(msg.sender);
        outputToken.safeTransfer(msg.sender, amount);
        deposits[msg.sender].amountRedeemed += amount;
    }

    function getRedeemableAmount(address account) internal view returns (uint withdrawable) {
        uint blocksSinceDeposit = (block.number).sub(deposits[account].blockDeposited);
        withdrawable = (deposits[account].amountDeposited)
            .mul(blocksSinceDeposit)
            .div(blocksToRelease);

        if (withdrawable > deposits[account].amountDeposited) {
            withdrawable = deposits[account].amountDeposited;
        }

        withdrawable = withdrawable.sub(deposits[account].amountRedeemed);
    }
}


contract FakeHegicStakingPool is ERC20("Fake sHEGIC", "FakeSHEGIC") {
    using SafeMath for uint;
    using SafeERC20 for ERC20;

    ERC20 public immutable inputToken;

    constructor(ERC20 _inputToken) {
        inputToken = _inputToken;
    }

    function deposit(uint amount) external {
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }
}


contract FakeZHegicToken is Ownable, ERC20("Fake zHEGIC", "FakeZHEGIC") {
    address public pool;

    modifier onlyPool {
        require(msg.sender == pool, "Only zLOT HEGIC pool can call this function");
        _;
    }

    function setPool (address _pool) external onlyOwner {
        pool = _pool;
    }

    function mint(address account, uint amount) external onlyPool {
        _mint(account, amount);
    }
}


/*
 * To simulate the floating conversion rate of zHEGIC/HEGIC, here we start with
 * 1:1, then increase 5% per block.
 * e.g. One blocks after the contract is created, 1 zHEGIC will worth 1.05 HEGIC;
 * another block after that, 1 zHEGIC will worth 1.10 HEGIC, etc.
 */
contract FakeHegicPoolV2 {
    using SafeMath for uint;
    using SafeERC20 for ERC20;

    ERC20 public immutable inputToken;
    FakeZHegicToken public immutable zToken;
    uint public blockCreated;

    constructor(ERC20 _inputToken, FakeZHegicToken _zToken) {
        inputToken = _inputToken;
        zToken = _zToken;
        blockCreated = block.number;
    }

    function deposit(uint amount) external returns (uint zTokenAmount) {
        uint blocksPassed = (block.number).sub(blockCreated);
        zTokenAmount = amount.mul(100).div(blocksPassed.mul(5).add(100));

        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        zToken.mint(msg.sender, zTokenAmount);
    }
}
