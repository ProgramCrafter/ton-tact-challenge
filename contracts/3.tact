import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  - amountOfBOutgoing = (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfAIncoming / decimal
  - If smart contract pool doesn't have enough jettons to trade, then it should send incoming jettons back to the user.
  - If smart contract receives a different jetton (neither A nor B) then throw an error.
  - Implement a getter that returns the number of jettons in the pool and one more to get the price of jetton A or jetton B.
  - Any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

fun send_to(jetton: Address, msg: TokenNotification, amount: Int) {
    send(SendParameters{
        to: jetton,
        value: 0,
        mode: SendRemainingValue,
        body: TokenTransfer{queryId:0, amount:amount, destination:msg.from,
            responseDestination:myAddress(), customPayload:null, forwardTonAmount:ton("0.01"), forwardPayload:emptySlice()}.toCell()
    });
}

contract Task3 with Deployable {
    admin: Address;
    aAmount: Int = 0;
    bAmount: Int = 0;
    jettonAddressA: Address;
    jettonAddressB: Address;
    
    const decimal: Int = 1000000000;
    
    init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
        self.admin = admin;
        self.jettonAddressA = newJettonAddressA;
        self.jettonAddressB = newJettonAddressB;
    }
    
    receive(msg: TokenNotification) {
        if (sender() == self.jettonAddressA) {
            if (msg.from == self.admin) {
                self.aAmount = self.aAmount + msg.amount;
                return;
            }
            let k: Int = (self.bAmount * self.decimal / self.aAmount) * msg.amount / self.decimal;
            
            if (self.bAmount >= k) {
                self.aAmount = self.aAmount + msg.amount;
                self.bAmount = self.bAmount - k;
                send_to(self.jettonAddressB, msg, k);
            } else {
                send_to(self.jettonAddressA, msg, msg.amount);
            }
        } else {
            require(sender() == self.jettonAddressB, "Unknown jetton");
            
            if (msg.from == self.admin) {
                self.bAmount = self.bAmount + msg.amount;
                return;
            }
            let k: Int = (self.aAmount * self.decimal / self.bAmount) * msg.amount / self.decimal;
            
            if (self.aAmount >= k) {
                self.bAmount = self.bAmount + msg.amount;
                self.aAmount = self.aAmount - k;
                send_to(self.jettonAddressA, msg, k);
            } else {
                send_to(self.jettonAddressB, msg, msg.amount);
            }
        }
    }
    
    get fun price(jetton: Address): Int {
        if (jetton == self.jettonAddressB) {
            return self.decimal * self.aAmount / self.bAmount;
        }
        return self.decimal * self.bAmount / self.aAmount;
    }
    
    get fun balance(jetton: Address): Int {
        if (jetton == self.jettonAddressA) {
            return self.aAmount;
        }
        return self.bAmount;
    }
}

