// SPDX-License-Identifier: MIT

interface Vm {
    function addr(uint256) external returns (address);
    function warp(uint256 x) external;
    function roll(uint x) external;
    function deal(address who, uint256 amount) external;
    function prank(address from) external;
    function startPrank(address from) external;
    function stopPrank() external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool, bool, bool, bool) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function expectCall(address, bytes calldata) external;
    function startBroadcast() external;
    function stopBroadcast() external;
}
