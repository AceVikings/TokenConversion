//SPDX-License-Identfier: UNLICESEND

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RaritySigner.sol";

contract Voyager1 is Ownable,RaritySigner{

    IERC721 PUFF;
    IERC20 xGRAV;
    IERC20 GRAV;

    struct tokenInfo{
        uint[] tokens;
        uint timestaked;
        uint amount;
    }

    uint public feeBalance;
    uint public FEE;

    address designatedSigner;

    mapping(uint=>uint) public tokenRarity;
    mapping(address=>mapping(uint=>tokenInfo)) public stakeInfo;
    mapping(address=>uint) public voyageId;
    mapping(address=>uint[]) public userStaked;

    bool public Paused;

    constructor(address _puff,address _xgrav,address _grav){
        PUFF = IERC721(_puff);
        xGRAV = IERC20(_xgrav);
        GRAV = IERC20(_grav);
    }

    function initializePuff(Rarity[] memory rarities) external {
        for(uint i=0;i<rarities.length;i++){
            require(getSigner(rarities[i])==designatedSigner,"Invalid signer");
            tokenRarity[rarities[i].tokenId] = rarities[i].rarity;
        }
    }

    function startVoyage(uint[][] memory tokenIds,uint[] memory price) external {
        require(tokenIds.length == price.length,"Length mismatch");
        require(msg.sender == tx.origin,"sender not origin");
        uint length  = tokenIds.length;
        uint amount = 0;
        for(uint i=0;i<length;i++){
            require(price[i] == 1 || price[i] == 2,"Invalid price");
            voyageId[msg.sender]++;
            amount += tokenIds[i].length * price[i] * 1 ether;
            uint inLength = tokenIds[i].length;
            for(uint j=0;i<inLength;i++){
                require(PUFF.ownerOf(tokenIds[i][j])==msg.sender,"Not owner");
            }
            stakeInfo[msg.sender][voyageId[msg.sender]] = tokenInfo(tokenIds[i],block.timestamp,price[i]);
        }
        feeBalance += amount * FEE/100;
        amount += amount * FEE/100;
        require(xGRAV.transferFrom(msg.sender,address(this),amount));
    }

    // function endVoyage(uint[] memory tokenIds) external {
    //     uint length = tokenIds.length;
    //     require(length < 60,"Can't end more than 60 puffs");
    //     uint Grav;
    //     uint xGrav;
    //     uint random = uint(vrf());
    //     for(uint i=0;i<length;i++){
    //         tokenInfo storage currToken = stakeInfo[tokenIds[i]];
    //         require(currToken.owner == msg.sender,"Not owner");
    //         require(block.timestamp - currToken.timestaked >= currToken.amount * 1 days);
    //         if (random % 100 < 5) {
    //             Grav += currToken.amount * 1 ether;
    //         }
    //         else{
    //             xGrav += currToken.amount * 1 ether;
    //         }
    //         PUFF.transferFrom(address(this),msg.sender,tokenIds[i]);
    //     }
    //     GRAV.transfer(msg.sender,Grav);
    //     xGRAV.transfer(msg.sender,xGrav);
    // }

    function vrf() private view returns (bytes32 result) {
        uint256[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            result := mload(memPtr)
        }
        return result;
    }

    function getUserStaked(address _user) external view returns(uint[] memory){
        return userStaked[_user];
    }

    function setPuff(address _puff) external onlyOwner{
        PUFF = IERC721(_puff);
    }

    function setxGrav(address _xgrav) external onlyOwner{
        xGRAV = IERC20(_xgrav);
    }

    function setGrav(address _grav) external onlyOwner{
        GRAV = IERC20(_grav);
    }

    function pauseContract(bool _pause) external onlyOwner{
        Paused = _pause;
    }

    function withdrawGrav(address _to) external onlyOwner{
        GRAV.transfer(_to,GRAV.balanceOf(address(this)));
    }

    function withdrawxGrav(address _to) external onlyOwner{
        uint amount = feeBalance;
        feeBalance = 0;
        xGRAV.transfer(_to,amount);
    }
}