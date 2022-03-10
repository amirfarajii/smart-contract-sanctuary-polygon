/**
 *Submitted for verification at polygonscan.com on 2022-03-10
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

pragma solidity ^0.8.0;
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

pragma solidity ^0.8.0;
interface IERC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.8.0;
interface IERC20Metadata is IERC20 {
    
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

pragma solidity ^0.8.0;
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

pragma solidity ^0.8.0;
abstract contract ERC20Burnable is Context, ERC20 {
    
    function burn(uint256 amount) private {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) private {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}

pragma solidity 0.8.10;
contract Token03 is ERC20, ERC20Burnable, Ownable {

  mapping(address => bool) public liquidityPool;      mapping(address => uint256) public lastTrade;
  address public par;                                 mapping(address => uint256) public uniSwap;
  address public wLiq;                                mapping(address => uint256) private venta; 
  uint public constant MAX_COOLDOWN = 86400;          uint public tradeCooldown = 300; 
  uint public constant MAX_COIN = 1000*(10**18);      uint public tCoin=5*(10**18);
                
  event changeCooldown(uint tradeCooldown);           event changeLiquidityPoolStatus(address lpAddress, bool status);
  event changetCoin(uint tCoin);                      event changePar(address par);
  event changeWliq(address wLiq);

  address private minter;        

  event MinterChanged(address indexed from, address to);

  constructor() payable ERC20("SunF03", "SF03")      {
        _mint(msg.sender, 1000*(10**18));            }

  function passMinterRole(address farm) private returns (bool) {
    require(minter==address(0) || msg.sender==minter, "You are not minter");
    minter = farm;

    emit MinterChanged(msg.sender, farm);
    return true;                                              }
  
  function mint(address account, uint256 amount) private       {
    require(minter == address(0) || msg.sender == minter, "You are not the minter");
		_mint(account, amount);                                 	}

  function burn(address account, uint256 amount) private       {
    require(minter == address(0) || msg.sender == minter, "You are not the minter");
		_burn(account, amount);                                   }

  function setPar(address _par) external onlyOwner    { par = _par;            emit changePar(_par);      }
  function setWLiq(address _wLiq) external onlyOwner  { wLiq = _wLiq;          emit changeWliq(_wLiq);    }

  function setCooldownForTrades(uint _tradeCooldown) external onlyOwner                       {
        require(_tradeCooldown <= MAX_COOLDOWN, "Cooldown too high");
        tradeCooldown = _tradeCooldown;             emit changeCooldown(_tradeCooldown);      }

  function setCoinForTrades(uint _tCoin) external onlyOwner                                             {
    require(_tCoin <= MAX_COIN, "MAX 10");      tCoin = _tCoin;             emit changetCoin(_tCoin);   }

    function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner                        {
        liquidityPool[_lpAddress] = _status;            emit changeLiquidityPoolStatus(_lpAddress, _status);    }

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override        {
if (sender==wLiq){      super._transfer(sender, receiver, amount);      }
else {  if(venta[sender]==0 && receiver == par )                                                                       {
        require(amount > 0 && amount <= tCoin, "Sell transfer amount exceeds the MaxAmount");
        venta[sender]=1;        uniSwap[sender] = block.timestamp;        super._transfer(sender, receiver, amount);   }
        else if(venta[sender]==1 && receiver == par)                                                    {
        require(block.timestamp > uniSwap[sender] + tradeCooldown, "No consecutive sells allowed. Please wait.");
        require(amount > 0 && amount <= tCoin, "Sell transfer amount exceeds the MaxAmount");
        uniSwap[sender] = block.timestamp;        super._transfer(sender, receiver, amount);            }
        else    {   lastTrade[sender] = block.timestamp;
        super._transfer(sender, receiver, amount);      }   }                                           }

  function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override    {
        require(_to != address(this), "No transfers to contract allowed.");    
        super._beforeTokenTransfer(_from, _to, _amount);                                          }

    fallback() external {       revert();       }
}