// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IRevenue {

    // --- Events ---
   
    // --- Function ---
    function transferUSDAOtoLiquity(address payable receiver, uint USDAOamount) external;
}