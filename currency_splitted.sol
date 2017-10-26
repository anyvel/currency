/*

    Copyright © 2016-2017 Dominique Climent, Florian Dubath

    This file is part of Monnaie-Leman Currency.

    Monnaie-Leman Wallet is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Monnaie-Leman Wallet is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Monnaie-Leman Wallet.  If not, see <http://www.gnu.org/licenses/>.

*/

pragma solidity ^0.4.11;

contract owned {
  address public owner;

  function owned() {
    owner = msg.sender;
  }
  
  function isOwner(address _user) constant returns (bool) {
    return _user==owner;
  }

  modifier onlyOwner {
    if (msg.sender != owner) revert();
    _;
  }
}


contract _template_ is owned {
  /* Public variables of the token */
  string  public standard       = '_fullname_';
  string  public name           = "_name_";
  string  public symbol         = "_symbol_";
  int8    public decimals       = 2;
  int16   public percent        = 0;
  int16   public percentLeg        = 0;
  uint256 public refillSupply   = 10;
  int256  public amountPledged  = 0;
  int256  public amountFonds    = 0;
  bool firstAdmin               = true;
  bool    public actif          = true;
  address public txAddr;
  uint256 minBalanceForAccounts = 1000000000000000000;

  /******** Arrays and lists ********/
  mapping (address => int256) public accountType;               // Account type 2 = special account 1 = Business 0 = Personal
  mapping (address => bool) public accountStatus;               // Account status
  mapping (address => int256) public balanceEL;                 // Balance in coins
  mapping (address => int256) public balanceCM;                 // Balance in Mutual credit
  mapping (address => int256) public limitCredit;               // Credit limit
  mapping (address => int256) public limitDebit;                // Debit limit
  
  mapping (address => mapping (address => int256)) public allowed;     // Array of allowed payements
  mapping (address => address[]) public allowMap;
  
  mapping (address => mapping (address => int256)) public requested;   // Array of requested payments
  mapping (address => address[]) public reqMap;
  
  mapping (address => mapping (address => int256)) public delegated;    // Array of authorized accounts
  mapping (address => address[]) public delegMap;
  
  mapping (address => mapping (address => int256)) public myAllowed;     // Array of allowed payements
  mapping (address => address[]) public myAllowMap;
  
  mapping (address => mapping (address => int256)) public myRequested;   // Array of requested payments
  mapping (address => address[]) public myReqMap;
  
  mapping (address => mapping (address => int256)) public myDelegated;   // Array of authorized accounts
  mapping (address => address[]) public myDelegMap;

  /* This generates a public event on the blockchain that will notify clients */
  event Transfer(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 recieved);
  event TransferCredit(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 recieved);
  event Approval(uint256 time, address indexed from, address indexed to, int256 value);
  event Delegation(uint256 time, address indexed from, address indexed to, int256 value);
  event Pledge(uint256 time, address indexed to, int256 recieved);
  event SetAccountParams(uint256 time, address target, bool accstatus, int256 acctype, int256 debit, int256 credit);
  event CreditLimitChange(uint256 time, address target, int256 amount);
  event DebitLimitChange(uint256 time, address target, int256 amount);
  event Refilled(uint256 time, address target, uint256 balance, uint256 limit);
  event DebugMsg(address indexed from, address indexed to, int256 value1, int value2);

  /* Initializes contract */
  function _template_(address taxAddress, int8 taxPercent, int8 taxPercentLeg) {
    txAddr = taxAddress;
    percent = taxPercent;
    percentLeg = taxPercentLeg;
    setFirstAdmin();
  }


function () payable{}

function repay(uint _amount) onlyOwner {
    uint amount = _amount * 1 ether;
    owner.transfer(amount); 
    
}



/********************************************************/
function setContractStatus(bool _actif) onlyOwner {
    actif=_actif;
}

/********************************************************/ 
/*   GLOBAL SETUP                     */

  function transferOwnership(address newOwner) onlyOwner {
    accountType[newOwner] = 2;
    accountStatus[newOwner] = true;
    owner = newOwner;
  }
               
  // Function to set the account to which the tax is paid
  function setTaxAccount(address _target) onlyOwner {
    txAddr = _target;
  }
  
  function getTaxAccount() constant returns (address) {
    return txAddr;
  }


  // Function to set the tax percentage
  function setTaxPercent(int16 _value) onlyOwner {
    if (_value < 0) revert();
    if (_value > 10000) revert();
    percent = _value;
  }
  
  function getTaxPercent() constant returns (int16) {
    return percent;
  }
  
  function setTaxPercentLeg(int16 _value) onlyOwner {
    if (_value < 0) revert();
    if (_value > 10000) revert();
    percentLeg = _value;
  }
  
  function getTaxPercentLeg() constant returns (int16) {
    return percentLeg;
  }

  // Set the threshold to refill an account
  function setRefillLimit(uint256 _minimumBalance) onlyOwner {
    minBalanceForAccounts = _minimumBalance * 1 ether;
  }

/********************************************************/
  /* Get the total amount of coin */
  function totalSupply() constant returns (int256 totalSupply) {
    totalSupply = amountPledged;
  }


/* Get the total balance of an account */
  function balanceOf(address _from) constant returns (int256 amount){
     return  balanceEL[_from] + balanceCM[_from];
  }
  
  
/* Account setup */  
  function setAccountParams(address _targetAccount, bool _accountStatus, int256 _accountType, int256 _debitLimit, int256 _creditLimit) {
    if (msg.sender!=owner){
        if (accountType[msg.sender] < 2  || !accountStatus[msg.sender]) revert();
    }
    
    accountStatus[_targetAccount] = _accountStatus;
    
    if (accountType[_targetAccount] != 2){
        accountType[_targetAccount] = _accountType;
        limitDebit[_targetAccount] = _debitLimit;
        limitCredit[_targetAccount] = _creditLimit;
        SetAccountParams(now, _targetAccount, _accountStatus, _accountType, _debitLimit, _creditLimit);
    }
    topUp(_targetAccount);
  }
  
  
/* Coin creation (Nantissement) */
  function pledge(address _to, int256 _value) {
    if (accountType[msg.sender] < 2) revert(); 
    if (!accountStatus[msg.sender]) revert();                                   // Check that only Special Accounts can pledge
    if (balanceEL[_to] + _value < balanceEL[_to]) revert();                     // Check for overflows
    balanceEL[_to] += _value;                                                   // Add the same to the recipient
    amountPledged += _value;
    
    Pledge(now, _to, _value);
    topUp(_to);
  }


/****************** Create Delegation Allowance and Rsquest *****************************/
  /* Allow _spender to withdraw from your account, multiple times, up to the _value amount.  */
  /* If called again the _amount is added to the allowance, if amount is negatif the allowance is deleted  */
  function approve(address _spender, int256 _amount) returns (bool success) {
    if (!accountStatus[msg.sender]) revert();
    if (_amount>=0){
        if ( allowed[msg.sender][_spender] == 0 ) {
            allowMap[msg.sender].push(_spender);
            myAllowMap[_spender].push(msg.sender);
        }
        allowed[msg.sender][_spender] += _amount;
        myAllowed[_spender][msg.sender] += _amount;
    } else {
         // delete allowance
        bool found = false;
	    uint i;
        for (i = 0; i<allowMap[msg.sender].length; i++){
                if (!found && allowMap[msg.sender][i] == _spender){
                    found=true;
                }
                
                if (found){
                    if (i < allowMap[msg.sender].length-1){
                         allowMap[msg.sender][i] = allowMap[msg.sender][i+1];
                    }
                }
        }
            
        if (found){
                 delete allowMap[msg.sender][allowMap[msg.sender].length-1]; // remove the last record from the mapping array
                 allowMap[msg.sender].length--;                            // adjust the length of the mapping array    
                 allowed[msg.sender][_spender] = 0;                          // remove the record from the mapping
        }
        
        // delete my allowance
        found = false;
        for (i = 0; i<myAllowMap[_spender].length; i++){
                if (!found && myAllowMap[_spender][i] == msg.sender){
                    found=true;
                }
                
                if (found){
                    if (i < myAllowMap[_spender].length-1){
                         myAllowMap[_spender][i] = myAllowMap[_spender][i+1];
                    }
                }
        }
            
        if (found){
                 delete myAllowMap[_spender][myAllowMap[_spender].length-1]; // remove the last record from the mapping array
                 myAllowMap[_spender].length--;                            // adjust the length of the mapping array    
                 myAllowed[_spender][msg.sender] = 0;                          // remove the record from the mapping
        }
    }
    Approval(now, msg.sender, _spender, _amount);
    topUp(msg.sender);
    topUp(_spender);
    return true;
  }
  
  /* Allow _spender to pay on behalf of you from your account, multiple times, each transaction bellow the limit. */
  /* If called again the limit is replaced by the new _amount, if _amount is 0 the delegation is removed */
  function delegate(address _spender, int256 _amount) {
    if (!accountStatus[msg.sender]) revert();
    
    if (_amount>0){
        if (delegated[msg.sender][_spender] == 0) {
          delegMap[msg.sender].push(_spender);
          myDelegMap[_spender].push(msg.sender);
        }
        delegated[msg.sender][_spender] = _amount;
        myDelegated[_spender][msg.sender] = _amount;
    } else {
        // delete delegation
        bool found = false;
	    uint i;
        for ( i = 0; i<delegMap[msg.sender].length; i++){
                if (!found && delegMap[msg.sender][i] == _spender){
                    found=true;
                }
                
                if (found){
                    if (i < delegMap[msg.sender].length-1){
                         delegMap[msg.sender][i] = delegMap[msg.sender][i+1];
                    }
                }
        }
            
        if (found){
                 delete delegMap[msg.sender][delegMap[msg.sender].length-1]; // remove the last record from the mapping array
                 delegMap[msg.sender].length--;                            // adjust the length of the mapping array    
                 delegated[msg.sender][_spender] = 0;                          // remove the record from the mapping
        }
        
        // delete my delegation
        found = false;
        for ( i = 0; i<myDelegMap[_spender].length; i++){
                if (!found && myDelegMap[_spender][i] == msg.sender){
                    found=true;
                }
                
                if (found){
                    if (i < myDelegMap[_spender].length-1){
                         myDelegMap[_spender][i] = myDelegMap[_spender][i+1];
                    }
                }
        }
            
        if (found){
                 delete myDelegMap[_spender][myDelegMap[_spender].length-1]; // remove the last record from the mapping array
                 myDelegMap[_spender].length--;                            // adjust the length of the mapping array    
                 myDelegated[_spender][msg.sender] = 0 ;                         // remove the record from the mapping
        }
        
        
    }
    topUp(msg.sender);
    topUp(_spender);
    Delegation(now, msg.sender, _spender, _amount);
  }
  
  /***********************************************************/
  /*  List access */

  function allowanceCount(address _owner) constant returns (uint256){
    return allowMap[_owner].length;
  }

  function myAllowanceCount(address _spender) constant returns (uint256){
    return allowMap[_spender].length;
  }

  function requestCount(address _owner) constant returns (uint256){
    return reqMap[_owner].length;
  }

  function myRequestCount(address _spender) constant returns (uint256){
    return myReqMap[_spender].length;
  }

  function delegationCount(address _owner) constant returns (uint256){
    return delegMap[_owner].length;
  }

  function myDelegationCount(address _spender) constant returns (uint256){
    return myDelegMap[_spender].length;
  }


  function payNant(address _from,address _to, int256 _value){
    if(!actif) revert();
    int16 tax_percent = percent;
    if (accountType[_to] == 1){
        tax_percent = percentLeg;
    }
    int256 tax = (_value * tax_percent) / 10000;
    int256 amount = _value - tax;
    if (!accountStatus[_from]) revert();
    if (!accountStatus[_to]) revert();
    if (!checkEL(_from, amount + tax)) revert();
    if (balanceEL[_to] + amount < balanceEL[_to]) revert(); //overflow check
    balanceEL[_from] -= amount + tax;         // Subtract from the sender
    balanceEL[_to] += amount;    
    balanceEL[txAddr] += tax;
     
    Transfer(now, _from, _to, amount+tax, tax, amount);        // Notify anyone listening that this transfer took place
    topUp(_to);
    topUp(_from);
  } 
  
  function payCM(address _from, address _to, int256 _value){
    if(!actif) revert();
    int16 tax_percent = percent;
    if (accountType[_to] == 1){
        tax_percent = percentLeg;
    }
    int256 tax = (_value * tax_percent) / 10000;
    int256 amount = _value - tax;
    if (!accountStatus[_from]) revert();
    if (!accountStatus[_to]) revert();
    if (!checkCMMin(_from, amount + tax)) revert();
    if (!checkCMMax(_to, amount)) revert();
    if (balanceCM[_to] + amount < balanceCM[_to]) revert(); //overflow check
    balanceCM[_from] -= amount + tax;         // Subtract from the sender
    balanceCM[_to] += amount;    
    balanceCM[txAddr] += tax;
    
    TransferCredit(now, _from, _to, amount+tax, tax, amount);  // Notify anyone listening that this transfer took place
    topUp(_to);
    topUp(_from);
  }


/* Add Request*/
  function insertRequest( address _from,  address _to,int256 _amount) {
    if (requested[_from][_to] == 0) {
      reqMap[_from].push(_to);
      myReqMap[_to].push(_from);
    }
    requested[_from][_to] += _amount;
    myRequested[_to][_from] += _amount;
    topUp(_to);
    topUp(_from);
  }

  function updateAllowed(address _from, address _to, int256 _value){
    allowed[_from][_to] += _value; 
    topUp(_to);
    topUp(_from);
  }
  
  function updateRequested(address _from, address _to, int256 _value){
    requested[_from][_to] += _value;
    myRequested[_to][_from] += _value;
    topUp(_to);
    topUp(_from);
  }
  
  function clear_request(address _from, address _to){
   bool found;
      uint i;
      if (requested[_from][_to]<=0){
            found = false;
            for (i = 0; i<reqMap[_from].length; i++){
                if (!found && reqMap[_from][i] == _to){
                    found=true;
                }
                
                if (found){
                    if (i < reqMap[_from].length-1){
                         reqMap[_from][i] = reqMap[_from][i+1];
                    }
                }
            }
            
            if (found){
                 delete reqMap[_from][reqMap[_from].length-1]; // remove the last record from the mapping array
                 reqMap[_from].length--;                            // adjust the length of the mapping array    
                 requested[_from][_to] = 0 ;                         // remove the record from the mapping
            }
      }
      
      if (myRequested[_to][_from]<=0){
            found = false;
            for (i = 0; i<myReqMap[_to].length; i++){
                if (!found && myReqMap[_to][i] == _from){
                    found=true;
                }
                
                if (found){
                    if (i < myReqMap[_to].length-1){
                         myReqMap[_to][i] = myReqMap[_to][i+1];
                    }
                }
            }
            
            if (found){
                 delete myReqMap[_to][myReqMap[_to].length-1]; // remove the last record from the mapping array
                 myReqMap[_to].length--;                       // adjust the length of the mapping array    
                 myRequested[_to][_from] = 0 ;               // remove the record from the mapping
            }
      }
    topUp(_to);
    topUp(_from);
}
  

  /*****  Private Functions   ***/

  // Function to set the type of an account
  function setFirstAdmin() internal {
    if (firstAdmin == false) revert();
    accountType[owner] = 2;
    accountStatus[owner] = true;
    firstAdmin = false;
  }

  function checkEL(address _addr, int256 _value) internal returns (bool) {
    int256 checkBalance = balanceEL[_addr] - _value;
    if (checkBalance < 0) {
      revert();
    } else {
      return true;
    }
  }

  function checkCM(address _addr, int256 _value) internal returns (bool) {
    int256 checkBalance = balanceCM[_addr] - _value;
    if (checkBalance < 0) {
      revert();
    } else {
      return true;
    }
  }

  function checkCMMin(address _addr, int256 _value) internal returns (bool) {
    int256 checkBalance = balanceCM[_addr] - _value;
    int256 limitCM = limitCredit[_addr];
    if (checkBalance < limitCM) {
      revert();
    } else {
      return true;
    }
  }

  function checkCMMax(address _addr, int256 _value) internal returns (bool) {
    int256 checkBalance = balanceCM[_addr] + _value;
    int256 limitCM = limitDebit[_addr];
    if (checkBalance > limitCM) {
      revert();
    } else {
      return true;
    }
  }

  // Top up function
  function topUp(address _addr) internal {
    uint amount = refillSupply * 1 ether;
    if (_addr.balance < minBalanceForAccounts){
      if(_addr.send(amount)) {
        Refilled(now, _addr, _addr.balance, minBalanceForAccounts);
      }
    }
  }
  
  // Refill Function
  function refill() internal {
    topUp(msg.sender);
  }
}


contract _template_Pay{

  _template_ account;
  
  function _template_Pay(address addr) {
    account = _template_(addr);
  }
  


  mapping (address => mapping (address => int256)) accepted;    // Array of requested payments accepted
  mapping (address => address[]) public acceptedMap;
  
  mapping (address => mapping (address => int256)) rejected;    // Array of requested payments rejected
  mapping (address => address[]) public rejectedMap;
 
  event Rejection(uint256 time, address indexed from, address indexed to, int256 value);


  function acceptedAmount(address _owner, address _spender) constant returns (int256 remaining) {
    return accepted[_owner][_spender];
  }

  function getAccepted(address _owner, uint index) constant returns (address _to) {
    return (acceptedMap[_owner][index]);
  }

  function acceptedCount(address _owner) constant returns (uint256){
    return acceptedMap[_owner].length;
  }
  
  function rejectedAmount(address _owner, address _spender) constant returns (int256 remaining) {
    return rejected[_owner][_spender];
  }

  function getRejected(address _owner, uint index) constant returns (address _to) {
    return (rejectedMap[_owner][index]);
  }

  function rejectedCount(address _owner) constant returns (uint256){
    return rejectedMap[_owner].length;
  }
  
  
  function allowance(address _owner, address _spender) constant returns (int256 remaining) {
    return account.allowed(_owner, _spender);
  }

  function getAllowance(address _owner, uint index) constant returns (address _to) {
    return account.allowMap(_owner, index);
  }

  function allowanceCount(address _owner) constant returns (uint256){
    return account.allowanceCount(_owner);
  }

  function myAllowance(address _spender, address _owner) constant returns (int256 remaining) {
    return account.allowed(_spender, _owner);
  }

  function myGetAllowance(address _spender, uint index) constant returns (address _to) {
    return account.allowMap(_spender, index);
  }

  function myAllowanceCount(address _spender) constant returns (uint256){
    return account.myAllowanceCount(_spender);
  }

  function request(address _owner, address _spender) constant returns (int256 remaining) {
    return account.requested(_owner, _spender);
  }

  function getRequest(address _owner, uint index) constant returns (address _to) {
    return account.reqMap(_owner, index);
  }

  function requestCount(address _owner) constant returns (uint256){
    return account.requestCount(_owner);
  }

  function myRequest(address _spender, address _owner) constant returns (int256 remaining) {
    return account.myRequested(_spender, _owner);
  }

  function myGetRequest(address _spender, uint index) constant returns (address _to) {
    return account.myReqMap(_spender, index);
  }

  function myRequestCount(address _spender) constant returns (uint256){
    return account.myRequestCount(_spender);
  }

  function delegation(address _owner, address _spender) constant returns (int256 remaining) {
    return account.delegated(_owner, _spender);
  }

  function getDelegation(address _owner, uint index) constant returns (address _to) {
    return account.delegMap(_owner, index);
  }

  function delegationCount(address _owner) constant returns (uint256){
    return account.delegationCount(_owner);
  }

  function myDelegation(address _spender, address _owner) constant returns (int256 remaining) {
    return account.myDelegated(_spender, _owner);
  }

  function myGetDelegation(address _spender, uint index) constant returns (address _to) {
    return account.myDelegMap(_spender, index);
  }

  function myDelegationCount(address _spender) constant returns (uint256){
    return account.myDelegationCount(_spender);
  }
  
  
  
  
  
/********************************************************/
/* Direct transfert of Coin and Mutual Credit*/
  
  /* Make payment in currency*/
  function transfer(address _to, int256 _value) {
    account.payNant(msg.sender,_to,_value);
  }

  /* Make payment in CM*/
  function transferCM(address _to, int256 _value) {
   account.payCM(msg.sender,_to,_value);
  }
  
/* Transfert "on behalf of" of Coin and Mutual Credit */
  /* Make Transfert "on behalf of"  in coins*/
  function transferOnBehalfOf(address _from, address _to, int256 _value) {
    if (account.delegated(_from, msg.sender) < _value) revert();
    account.payNant(_from,_to,_value);
  }
  
   /* Make  Transfert "on behalf of" in Mutual Credit */
  function transferCMOnBehalfOf(address _from, address _to, int256 _value) {
    if (account.delegated(_from, msg.sender) < _value) revert();
    account.payCM(_from,_to,_value);
  }

/* Transfert request of Coin and Mutual Credit */
  // Send _value Coin from address _from to the sender
  function transferFrom(address _from, int256 _value) {
   if (account.allowed(_from, msg.sender) >= _value && account.balanceEL(_from)>=_value) {
     account.payNant(_from, msg.sender,_value);
     account.updateAllowed(_from, msg.sender,-_value);     // substract the value from the allowed
    } else {
      account.insertRequest(_from,  msg.sender, _value);                   // if allowed is not enough (or do not exist) create a request
    }
  }
  
  // Send _value Mutual Credit from address _from to the sender
  function transferCMFrom(address _from, int256 _value) {
    if (account.allowed(_from, msg.sender) >= _value  && account.balanceCM(_from)>=_value) {
     account.payCM(_from, msg.sender,_value);
     account.updateAllowed(_from, msg.sender,-_value);     // substract the value from the allowed
    } else {
      account.insertRequest(_from,  msg.sender, _value);                   // if allowed is not enough (or do not exist) create a request
    }
  }
  

/*       Request handling        */
  /* Accept and pay in coin a payment request (also delete the request if needed and add it to the accepted list) */
  function payRequest(address _to, int256 _value) {
    account.payNant(msg.sender,_to,_value);
    account.updateRequested(msg.sender, _to,-_value);
    
    if (accepted[_to][msg.sender] == 0) {
         acceptedMap[_to].push(msg.sender);
    }
    accepted[_to][msg.sender] += _value;
   
    account.clear_request(msg.sender,_to);
      
  }
  
  
  /* Accept and pay in mutual credit a payment request (also delete the request if needed and add it to the accepted list) */
  function payRequestCM(address _to, int256 _value) {
    account.payCM(msg.sender,_to,_value);
    account.updateRequested(msg.sender, _to,-_value);
    
    if (accepted[_to][msg.sender] == 0) {
         acceptedMap[_to].push(msg.sender);
    }
    accepted[_to][msg.sender] += _value;
    
    account.clear_request(msg.sender,_to);

  }
  

  /* Discard a payement request put it into the rejected request. */
  function cancelRequest(address _to) {
    if (!account.accountStatus(msg.sender)) revert();
    int256 amount = account.requested(msg.sender,_to);
    if (amount>0){
        if (rejected[_to][msg.sender] == 0) {
               rejectedMap[_to].push(msg.sender);
        }
        
        account.updateRequested(msg.sender, _to,-amount);
        rejected[_to][msg.sender] += amount;
        
        Rejection(now, msg.sender, _to, amount);
        account.clear_request(msg.sender,_to);
    }
  }
  
  
  /* Discard acceptation information */
  function discardAcceptedInfo(address _spender){
    if (!account.accountStatus(msg.sender)) revert();
    bool found = false;
    for (uint i = 0; i<acceptedMap[msg.sender].length; i++){
        if (!found && acceptedMap[msg.sender][i] == _spender){
            found=true;
        }
        
        if (found){
            if (i < acceptedMap[msg.sender].length-1){
                 acceptedMap[msg.sender][i] = acceptedMap[msg.sender][i+1];
            }
        }
    }
    
    if (found){
         delete acceptedMap[msg.sender][acceptedMap[msg.sender].length-1]; // remove the last record from the mapping array
         acceptedMap[msg.sender].length--;                                 // adjust the length of the mapping array    
         accepted[msg.sender][_spender] = 0;                                // remove the record from the mapping
    }
  }
  
  /* Discard rejected incormation */
  function discardRejectedInfo(address _spender){
    if (!account.accountStatus(msg.sender)) revert();
    bool found = false;
    for (uint i = 0; i<rejectedMap[msg.sender].length; i++){
        if (!found && rejectedMap[msg.sender][i] == _spender){
            found=true;
        }
        
        if (found){
            if (i < rejectedMap[msg.sender].length-1){
                 rejectedMap[msg.sender][i] = rejectedMap[msg.sender][i+1];
            }
        }
    }
    
    if (found){
         delete rejectedMap[msg.sender][rejectedMap[msg.sender].length-1]; // remove the last record from the mapping array
         rejectedMap[msg.sender].length--;                                 // adjust the length of the mapping array    
         rejected[msg.sender][_spender] = 0;                               // remove the record from the mapping
    }
  }
}
