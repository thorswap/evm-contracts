// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {IChainflipVault} from "../../interfaces/IChainflipVault.sol";
import {TSAggregator_V6} from "../abstract/TSAggregator_V6.sol";

contract TSAggregatorChainflip_V2 is Owners, TSAggregator_V6 {
    using SafeTransferLib for address;

    struct cfAsset {
        uint32 dstChain;
        uint32 dstToken;
    }

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

    // cross-chain routers implementing ThorchainRouterV4 functions
    IThorchainRouterV4[] public routers;
    IChainflipVault public chainflipVault;

    // converts token address received from Thorchain into a cfAsset struct
    mapping(address => cfAsset) public cfAssets;

    constructor(address _ttp) TSAggregator_V6(_ttp) {
        _setOwner(msg.sender, true);

        addRouter(0xD37BbE5744D730a1d98d8DC97c42F0Ca46aD7146); // thorchain router eth
        addRouter(0xe3985E6b61b814F7Cdb188766562ba71b446B46d); // mayachain router eth
        setCfVault(0xF5e10380213880111522dd0efD3dbb45b9f62Bcc); // chainflip router eth

        // initial cfAssets mapping
        addCfAsset(0xa5f2211B9b8170F694421f2046281775E8468044, 5, 9); // ETH.THOR -> SOL.SOL
        addCfAsset(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 5, 10); // ETH.USDC -> SOL.USDC
        addCfAsset(0x6B175474E89094C44Da98b954EedeAC495271d0F, 4, 6); // ETH.DAT -> ARB.ETH
        addCfAsset(0xdAC17F958D2ee523a2206206994597C13D831ec7, 4, 7); // ETH.USDT -> ARB.USDC
        addCfAsset(0x826180541412D574cf1336d22c0C0a287822678A, 1, 2); // ETH.FLIP -> ETH.FLIP
        addCfAsset(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 2, 4); // ETH.UNI -> DOT.DOT
    }

    function addRouter(address _routerAddress) public isOwner {
        routers.push(IThorchainRouterV4(_routerAddress));
    }

    function getRouterAddress(uint16 index) public view returns (address) {
        require(index < routers.length, "Invalid router index");
        return address(routers[index]);
    }

    function setCfVault(address _vault) public isOwner {
        chainflipVault = IChainflipVault(_vault);
    }

    function addCfAsset(
        address _token,
        uint32 _dstChain,
        uint32 _dstToken
    ) public isOwner {
        cfAssets[_token] = cfAsset(_dstChain, _dstToken);
    }

    function getCfAsset(address _token) public view returns (uint32, uint32) {
        return (cfAssets[_token].dstChain, cfAssets[_token].dstToken);
    }

    function cfReceive(
        uint32 srcChain, // Source chain for the swap
        bytes calldata srcAddress, // Address that initiated the swap on the source chain.
        bytes calldata message, // Message that is passed to the destination address on the destination. chain
        address token, // Address of the token transferred to the receiver. A value of0xEeee...eeEEeE represents the native token.
        uint256 amount // Amount of the destination token transferred to the receiver. If it's the native token, the amount value will equal the msg.value.
    ) public payable nonReentrant {
        uint _routerIndex;
        address _vault;
        string memory _memo;

        // decode the message and validate format
        try this.decodeMessage(message) returns (
            uint decodedRouterIndex,
            address decodedVault,
            string memory decodedMemo
        ) {
            _routerIndex = decodedRouterIndex;
            _vault = decodedVault;
            _memo = decodedMemo;
        } catch {
            revert("Invalid message format");
        }

        require(_routerIndex < routers.length, "Invalid router index");

        if (msg.value > 0) {
            uint _safeAmount = takeFeeGas(msg.value);
            routers[_routerIndex].depositWithExpiry{value: _safeAmount}(
                payable(_vault),
                address(0),
                _safeAmount,
                _memo,
                type(uint).max
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
                type(uint).max
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
        // check if token matches an entry in cfAssets
        (uint32 _dstChain, uint32 _dstToken) = getCfAsset(token);
        uint256 _safeAmount = takeFeeGas(msg.value);

        if (_dstChain == 0 && _dstToken == 0) {
            // if token did not match an entry, send eth to recipient "to"
            to.safeTransferETH(_safeAmount);
            emit SwapOut(to, token, _safeAmount, amountOutMin);
        } else {
            // call xSwapNative on chainflipVault
            try
                chainflipVault.xSwapNative{value: _safeAmount}(
                    _dstChain,
                    abi.encode(to),
                    _dstToken,
                    ""
                )
            {
                emit SwapOut(to, token, msg.value, amountOutMin);
            } catch {
                to.safeTransferETH(_safeAmount);
            }
        }
    }

    // helper function to decode the message
    function decodeMessage(
        bytes calldata message
    )
        public
        pure
        returns (uint routerIndex, address vault, string memory memo)
    {
        return abi.decode(message, (uint, address, string));
    }
}