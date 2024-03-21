// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract TSMemoGenLedger_V1 {
    function swapMemo(
        string calldata asset, // BNB.BNB
        string calldata destAddr, // bnb108n64knfm38f0mm23nkreqqmpc7rpcw89sqqw5
        string calldata limit, // 1231230/2/6
        string calldata affiliate // t:30
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "=:",
                    asset,
                    ":",
                    destAddr,
                    ":",
                    limit,
                    ":",
                    affiliate
                )
            );
    }

    // Function to hash UTF-8 memo
    function hashMemo(string calldata memo) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(memo));
    }
}
