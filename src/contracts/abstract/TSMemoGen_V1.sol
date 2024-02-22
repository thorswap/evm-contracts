// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract TSMemoGen_V1 {
    function swapMemo(
        string calldata asset, // BNB.BNB
        string calldata destAddr, // bnb108n64knfm38f0mm23nkreqqmpc7rpcw89sqqw5
        string calldata limit, // 1231230/2/6
        string calldata affiliate, // t
        string calldata fee // 30
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked(
                "=:",
                asset,
                ":",
                destAddr,
                ":",
                limit,
                ":",
                affiliate,
                ":",
                fee
            )
        );

        return memo;
    }

    // Generic memo for swaps and loans
    // e.g. SWAP:BNB.BNB:bnb108n64knfm38f0mm23nkreqqmpc7rpcw89sqqw5:1231230/2/6:t:30
    function genericMemo(
        string calldata action, // SWAP
        string calldata asset, // BNB.BNB
        string calldata destAddr, // bnb108n64knfm38f0mm23nkreqqmpc7rpcw89sqqw5
        string calldata limit, // 1231230/2/6
        string calldata affiliate, // t
        string calldata fee // 30
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked(
                action,
                ":",
                asset,
                ":",
                destAddr,
                ":",
                limit,
                ":",
                affiliate,
                ":",
                fee
            )
        );

        return memo;
    }

    // Memo with explicit parameters for streaming swaps
    // e.g. =:r:oleg:0/3/0:t:0
    function swapStreamingMemo(
        string calldata action, // =
        string calldata asset, // r
        string calldata destAddr, // oleg - thorname supported
        string calldata limit, // 0
        string calldata interval, // 3
        string calldata quantity, // 0 - let the protocol decide how many subswaps
        string calldata affiliate, // t
        string calldata fee // 0
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked(
                action,
                ":",
                asset,
                ":",
                destAddr,
                ":",
                limit,
                "/",
                interval,
                "/",
                quantity,
                ":",
                affiliate,
                ":",
                fee
            )
        );

        return memo;
    }

    // Memo with dex aggregation parameters
    // e.g. =:e:0x31b27d6d447b079b716b889ff438c311e5f14eb4:61738022:t:15:15:302:342498409988635794847100
    function swapDexAggMemo(
        string calldata action, // =
        string calldata asset, // e
        string calldata destAddr, // 0x31b27d6d447b079b716b889ff438c311e5f14eb4
        string calldata limit, // 61738022
        string calldata affiliate, // t
        string calldata fee, // 15
        string calldata aggregator, // 15 - fuzzy matching with last digits from aggregator whitelist
        string calldata targetAsset, // 302 - fuzzy matching with last digits from tokens whitelist
        string calldata minAmountOut // 342498409988635794847100 - min amount out passed to the aggregator contract, prevents sandwich attacks
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked(
                action,
                ":",
                asset,
                ":",
                destAddr,
                ":",
                limit,
                ":",
                affiliate,
                ":",
                fee,
                ":",
                aggregator,
                ":",
                targetAsset,
                ":",
                minAmountOut
            )
        );

        return memo;
    }

    // Memo for savers with affiliate parameters
    // e.g. +:ETH/ETH::t:1
    function saversMemo(
        string calldata action, // +
        string calldata asset, // ETH/ETH
        string calldata basisPoints, // (empty for adds)
        string calldata affiliate, // t
        string calldata fee // 1
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked(
                action,
                ":",
                asset,
                ":",
                basisPoints,
                ":",
                affiliate,
                ":",
                fee
            )
        );

        return memo;
    }

    // Memo to add dual-sided liquidity
    // e.g. +:ETH.THOR-044:thor1s298k6p4rdn7ncwlkzce8x75zsryu5k45aw33y:t:0
    function addLiquidityMemo(
        string calldata asset, // ETH.THOR-044
        string calldata pairedAddr, // thor1s298k6p4rdn7ncwlkzce8x75zsryu5k45aw33y
        string calldata affiliate, // t
        string calldata fee // 0
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked(
                "+:",
                asset,
                ":",
                pairedAddr,
                ":",
                affiliate,
                ":",
                fee
            )
        );

        return memo;
    }

    // Memo to withdraw dual-sided liquidity
    // e.g. -:ETH.THOR-044:10000:THOR.RUNE
    function withdrawLiquidityMemo(
        string calldata asset, // ETH.THOR-044
        string calldata basisPoints, // 10000 (100%)
        string calldata withdrawAsset // THOR.RUNE
    ) public pure returns (string memory) {
        string memory memo = string(
            abi.encodePacked("-:", asset, ":", basisPoints, ":", withdrawAsset)
        );

        return memo;
    }

    // Function to hash UTF-8 memo
    function hashMemo(string calldata memo) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(memo));
    }
}
