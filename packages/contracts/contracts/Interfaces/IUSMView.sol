
pragma solidity 0.6.11;

interface IUSMView {

function usmMint(uint ethIn) external view
returns (uint price, uint usmOut, uint adjShrinkFactor);
} 