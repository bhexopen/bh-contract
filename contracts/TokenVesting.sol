pragma solidity ^0.4.24;

import "./SafeERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";


/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract TokenVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    event Released(uint256 amount);
    event Revoked();

    // beneficiary of tokens after they are released
    address public beneficiary;

    uint256 public cliff;
    uint256 public start;
    uint256 public duration;
    uint256 public phased;

    bool public revocable;

    mapping (address => uint256) public released;
    mapping (address => bool) public revoked;

    /**
    * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
    * _beneficiary, gradually in a phased fashion until _start + _duration. By then all
    * of the balance will have vested.
    * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _start the time (as Unix time) at which point vesting starts
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _phased duration in seconds of the every release stage
    * @param _revocable whether the vesting is revocable or not
    */
    constructor(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _phased,
        bool _revocable
    )
        public
    {
        require(_beneficiary != address(0));
        require(_cliff <= _duration);
        require(_phased <= _duration.sub(_cliff));

        beneficiary = _beneficiary;
        revocable = _revocable;
        duration = _duration;
        cliff = _start.add(_cliff);
        start = _start;
        phased = _phased;
    }

    /**
    * @notice Transfers vested tokens to beneficiary.
    * @param _token ERC20 token which is being vested
    */
    function release(ERC20 _token) public {
        uint256 unreleased = releasableAmount(_token);

        require(unreleased > 0);

        released[_token] = released[_token].add(unreleased);

        _token.safeTransfer(beneficiary, unreleased);

        emit Released(unreleased);
    }

    /**
    * @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param _token ERC20 token which is being vested
    */
    function revoke(ERC20 _token) public onlyOwner {
        require(revocable);
        require(!revoked[_token]);

        uint256 balance = _token.balanceOf(address(this));

        uint256 unreleased = releasableAmount(_token);
        uint256 refund = balance.sub(unreleased);

        revoked[_token] = true;

        _token.safeTransfer(owner, refund);

        emit Revoked();
    }

    /**
    * @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param _token ERC20 token which is being vested
    */
    function releasableAmount(ERC20 _token) public view returns (uint256) {
        return vestedAmount(_token).sub(released[_token]);
    }

    /**
    * @dev Calculates the amount that has already vested.
    * @param _token ERC20 token which is being vested
    */
    function vestedAmount(ERC20 _token) public view returns (uint256) {
        uint256 currentBalance = _token.balanceOf(this);
        uint256 totalBalance = currentBalance.add(released[_token]);

        uint256 totalPhased = (start.add(duration).sub(cliff)).div(phased);
        uint256 everyPhasedReleaseAmount = totalBalance.div(totalPhased);

        if (block.timestamp < cliff.add(phased)) {
            return 0;
        } else if (block.timestamp >= start.add(duration) || revoked[_token]) {
            return totalBalance;
        } else {
            uint256 currentPhased = block.timestamp.sub(cliff).div(phased);
            return everyPhasedReleaseAmount.mul(currentPhased);
        }
    }
}
