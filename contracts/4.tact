import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining;
}

message(0x5fcc3d14) Transfer {
    queryId: Int as uint64;
    newOwner: Address;
    responseDestination: Address;
    customPayload: Cell?;
    forwardAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message NftWithdrawal {
    queryId: Int as uint64;
    nftAddress: Address;
}

struct NFTData {
    addr: Address;
    owner: Address;
}

contract Task4 with Deployable {
    seed: Int as uint128;
    hodl: NFTData?;
    deadline: Int as uint32;
    
    init(seed: Int) {
        self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
        self.deadline = 0;
    }
    
    receive(msg: OwnershipAssigned) {
        if (self.hodl != null) {
            self.send_nft(sender(), msg.prevOwner, msg.queryId);
            return;
        }
        self.hodl = NFTData{addr: sender(), owner: msg.prevOwner};
        self.deadline = now() + msg.forwardPayload.loadUint(32);
    }
    
    receive(msg: NftWithdrawal) {
        require(self.hodl != null, "Invalid sender");
        require(sender() == (self.hodl!!).owner, "Invalid sender");
        if (now() < self.deadline) {
            self.reply("NFT is still locked".asComment());
            return;
        }
        self.send_nft((self.hodl!!).addr, (self.hodl!!).owner, msg.queryId);
        self.hodl = null;
    }
    
    fun send_nft(addr: Address, to: Address, q: Int) {
        send(SendParameters{
            to: addr,
            value: 0,
            mode: SendRemainingBalance,
            body: Transfer{queryId:q, newOwner:to, responseDestination:to, customPayload:null, forwardAmount:0, forwardPayload:emptySlice()}.toCell()
        });
    }
    
    get fun time(): Int {
        return self.deadline - now();
    }
    
    get fun nft(): Address? {
        if (self.hodl == null) {return null;}
        return (self.hodl!!).addr;
    }
    
    get fun owner(): Address? {
        if (self.hodl == null) {return null;}
        return (self.hodl!!).owner;
    }
}

