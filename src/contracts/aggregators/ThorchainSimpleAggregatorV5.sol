// SPDX-License-Identifier: MIT
// -------------------
// Aggregator Version: 2.0
// -------------------
pragma solidity 0.8.22;

// ERC20 Interface
interface iERC20 {
  function balanceOf(address) external view returns (uint256);
}

// ROUTER Interface
interface iROUTER {
  function depositWithExpiry(
    address payable vault,
    address asset,
    uint amount,
    string memory memo,
    uint expiration
  ) external payable;
}

// Sushi Interface
interface iSWAPROUTER {
  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;

  function swapExactETHForTokens(
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external payable;
}

// THORChain_Aggregator is permissionless
contract ThorchainSimpleAggregatorV5 {
  uint256 private constant _NOT_ENTERED = 1;
  uint256 private constant _ENTERED = 2;
  uint256 private _status;

  address private ETH = address(0);
  address public WETH;
  iSWAPROUTER public swapRouter;
  address public owner;

  modifier nonReentrant() {
    require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
    _status = _ENTERED;
    _;
    _status = _NOT_ENTERED;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Caller is not the owner");
    _;
  }

  constructor(address _weth, address _swapRouter) {
    _status = _NOT_ENTERED;
    WETH = _weth;
    swapRouter = iSWAPROUTER(_swapRouter);
    owner = msg.sender;
  }

  receive() external payable {}

  function rescueFunds(
    address asset,
    uint256 amount,
    address destination
  ) public onlyOwner {
    if (asset == address(0)) {
      payable(destination).transfer(amount);
    } else {
      (bool success, ) = asset.call(
        abi.encodeWithSignature(
          "transfer(address,uint256)",
          destination,
          amount
        )
      );
      require(success, "Transfer failed");
    }
  }

  //############################## IN ##############################

  function swapIn(
    address tcVault,
    address tcRouter,
    string calldata tcMemo,
    address token,
    uint amount,
    uint amountOutMin,
    uint256 deadline
  ) public nonReentrant {
    uint256 _safeAmount = safeTransferFrom(token, amount); // Transfer asset
    safeApprove(token, address(swapRouter), amount);
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = WETH;
    swapRouter.swapExactTokensForETH(
      _safeAmount,
      amountOutMin,
      path,
      address(this),
      deadline
    );
    _safeAmount = address(this).balance;
    iROUTER(tcRouter).depositWithExpiry{value: _safeAmount}(
      payable(tcVault),
      ETH,
      _safeAmount,
      tcMemo,
      deadline
    );
  }

  //############################## OUT ##############################

  // V4 swapOut kept for backward compatibility
  function swapOut(
    address token,
    address to,
    uint256 amountOutMin
  ) public payable nonReentrant {
    address[] memory path = new address[](2);
    path[0] = WETH;
    path[1] = token;
    swapRouter.swapExactETHForTokens{value: msg.value}(
      amountOutMin,
      path,
      to,
      type(uint).max
    );
  }

  function swapOutV5(
    address fromAsset,
    uint256 fromAmount,
    address toAsset,
    address recipient,
    uint256 amountOutMin,
    bytes memory payload,
    string memory originAddress
  ) public payable nonReentrant {
    address[] memory path = new address[](2);

    // you can do something with originAddress: https://gitlab.com/thorchain/thornode/-/merge_requests/3339#note_1884273837

    if (fromAsset == address(0)) {
      // received ETH, swap to toToken or do as you please
      path[0] = WETH;
      path[1] = toAsset;

      if (payload.length == 0) {
        // no payload, process without wasting gas
        swapRouter.swapExactETHForTokens{value: msg.value}(
          amountOutMin,
          path,
          recipient,
          type(uint).max
        );
      } else {
        // do something with your payload like parse to an aggregator specific structure
        swapRouter.swapExactETHForTokens{value: msg.value}(
          amountOutMin,
          path,
          recipient,
          type(uint).max
        );
      }
    } else {
      // received an ERC20, swap to ETH or do as you please
      path[0] = fromAsset;
      path[1] = WETH;
      safeApprove(fromAsset, address(swapRouter), 0); // best practice
      safeApprove(fromAsset, address(swapRouter), fromAmount);

      if (payload.length == 0) {
        // no payload, process without wasting gas
        // UniV2 transfers from 'msg.sender', so we need a low-level `.call` to change the msg.sender from the target's perspective
        (bool aggSuccess, ) = address(swapRouter).call(
          abi.encodeWithSignature(
            "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
            fromAmount,
            amountOutMin,
            path,
            recipient,
            type(uint).max // Assuming using the maximum uint256 value as the deadline
          )
        );
        require(aggSuccess, "swapExactTokensForETH failed");
      } else {
        // do something with your payload like parse to an aggregator specific structure
        // UniV2 transfers from 'msg.sender', so we need a low-level `.call` to change the msg.sender from the target's perspective
        (bool success, ) = address(swapRouter).call(
          abi.encodeWithSignature(
            "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
            fromAmount,
            amountOutMin,
            path,
            recipient,
            type(uint).max // Assuming using the maximum uint256 value as the deadline
          )
        );
        require(success, "swapExactTokensForETH failed");
      }
    }
  }

  //############################## HELPERS ##############################

  // Safe transferFrom in case asset charges transfer fees
  function safeTransferFrom(
    address _asset,
    uint _amount
  ) internal returns (uint amount) {
    uint _startBal = iERC20(_asset).balanceOf(address(this));
    (bool success, bytes memory data) = _asset.call(
      abi.encodeWithSignature(
        "transferFrom(address,address,uint256)",
        msg.sender,
        address(this),
        _amount
      )
    );
    require(success && (data.length == 0 || abi.decode(data, (bool))));
    return (iERC20(_asset).balanceOf(address(this)) - _startBal);
  }

  function safeApprove(
    address _asset,
    address _address,
    uint _amount
  ) internal {
    (bool success, ) = _asset.call(
      abi.encodeWithSignature("approve(address,uint256)", _address, _amount)
    ); // Approve to transfer
    require(success);
  }
}
