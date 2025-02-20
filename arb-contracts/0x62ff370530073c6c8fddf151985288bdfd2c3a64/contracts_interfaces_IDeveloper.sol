// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDeveloper {
    function addDeveloper ( address dev ) external;
    function devCount (  ) external view returns ( uint256 );
    function developerIds ( address ) external view returns ( uint256 );
    function developers ( uint256 ) external view returns ( address );
    function distribute (  ) external;
    function distributeToken ( address tokenAddress ) external;
    function isDeveloper ( address dev ) external view returns ( bool );
    function owner (  ) external view returns ( address );
    function removeDeveloper ( address dev ) external;
    function renounceOwnership (  ) external;
    function router (  ) external view returns ( address );
    function stake (  ) external view returns ( address );
    function token (  ) external view returns ( address );
    function transferOwnership ( address newOwner ) external;
}