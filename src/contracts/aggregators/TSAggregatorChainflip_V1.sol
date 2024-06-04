// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {TSAggregator_V4} from "../abstract/TSAggregator_V4.sol";

contract TSAggregatorChainflip_V1 is Owners, TSAggregator_V4 {
    using SafeTransferLib for address;

    // cross-chain routers implementing ThorchainRouterV4 functions
    IThorchainRouterV4[] public routers;

    struct aggregationCCM {
        uint routerIndex;
        address vault;
        string memo;
    }

    event CFReceive(
        uint32 srcChain,
        bytes srcAddress,
        address token,
        uint256 amount,
        address router,
        string memo
    );

    event SwapOut(address to, address token, uint256 amount, uint256 fee);

    constructor(address _ttp) TSAggregator_V4(_ttp) {
        _setOwner(msg.sender, true);
    }

    function addRouter(address _routerAddress) public isOwner {
        routers.push(IThorchainRouterV4(_routerAddress));
    }

    function getRouterAddress(
        uint16 index
    ) public view returns (address) {
        require(index < routers.length, "Invalid router index");
        return address(routers[index]);
    }

    function cfReceive(
        uint32 srcChain, // Source chain for the swap
        bytes calldata srcAddress, // Address that initiated the swap on the source chain.
        bytes calldata message, // Message that is passed to the destination address on the destination. chain
        address token, // Address of the token transferred to the receiver. A value of0xEeee...eeEEeE represents the native token.
        uint256 amount // Amount of the destination token transferred to the receiver. If it's the native token, the amount value will equal the msg.value.
    ) public payable nonReentrant {
        (uint _routerIndex, address _vault, string memory _memo) = abi.decode(
            message,
            (uint, address, string)
        );
        require(_routerIndex < routers.length, "Invalid router index");

        if (msg.value > 0) {
            uint _safeAmount = takeFeeGas(msg.value);
            routers[_routerIndex].depositWithExpiry{value: _safeAmount}(
                payable(_vault),
                address(0),
                _safeAmount,
                _memo,
                block.timestamp + 1
            );
        } else {
            uint256 _safeAmount = takeFeeToken(token, amount);
            token.safeApprove(address(routers[_routerIndex]), 0);
            token.safeApprove(address(routers[_routerIndex]), _safeAmount);

            routers[_routerIndex].depositWithExpiry{value: 0}(
                payable(_vault),
                token,
                _safeAmount,
                _memo,
                block.timestamp + 1
            );
        }

        emit CFReceive(
            srcChain,
            srcAddress,
            token,
            amount,
            address(routers[_routerIndex]),
            _memo
        );
    }

    // Swap out from Router V4, only gas asset to deposit channel
    function swapOut(
        address token,
        address to,
        uint256 amountOutMin
    ) public payable nonReentrant {
        uint256 amount = takeFeeToken(token, amountOutMin);
        to.safeTransferETH(amount);
        emit SwapOut(to, token, amount, amountOutMin);
    }
}
