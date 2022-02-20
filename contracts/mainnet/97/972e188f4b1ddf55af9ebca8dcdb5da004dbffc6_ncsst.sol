/**
 *Submitted for verification at polygonscan.com on 2022-02-19
*/

pragma solidity ^0.8.7;
contract ncsst{

mapping (address => uint) public balances;
mapping (address => mapping (address=>uint)) public allowance;
 uint public totalSupply = 21000000000 * 10 ** 8;
 string public name = "NecessiT";
 string public symbol = "NCSST";
 uint public decimals = 8;
 constructor(){
     balances[msg.sender] = totalSupply;
 }
 
 function balanceOf(address owner) public view returns (uint){
     return balances[owner];
 }
 
 event Transfer(address indexed from, address indexed to, uint value);
 event Approval(address indexed owner, address indexed spender, uint value);
 
 function transfer(address to, uint value) public returns(bool){
     require (balanceOf(msg.sender) >= value, 'balance too low');
  balances[to] = balances[to]+ value;
  balances[msg.sender] =  balances[msg.sender]-value;
  emit Transfer(msg.sender, to, value);
  return true;
 }
 
 function transferFrom(address from, address to, uint value) public returns(bool){
     
     require(balanceOf(from)>=value, 'balance too low');
     require(allowance[from][msg.sender] >= value, 'allowance to low');
     balances[to] += value;
     balances[from] -= value;
     emit Transfer(from, to, value);
     return true;
 }
 
 function approve(address spender, uint value) public returns(bool){
     
     allowance[msg.sender][spender] = value; 
     emit Approval(msg.sender, spender, value);
     return true;
 }


 
}