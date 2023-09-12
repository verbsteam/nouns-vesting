# Noun Vesting

A helper contract for Nouns DAO to transfer Nouns to partners and community members, with the following requirements:

Nouns sender (Nouns DAO) can:

- Set a vesting end timestamp.
- Set a claiming period end timestamp, afterwhich if recipient hasn't claimed their tokens, the DAO can withdraw them.
- Set a price per token the recipient needs to pay to claim their Nouns.
- Lock any vesting contract such that no more Nouns can be sent to it.
- Nouns DAO can clawback Nouns until the vesting end timestamp ???

Recipient can:

- Delegate the Nouns held in this contract to any Ethereum address they like, as soon as they are sent to this contract.
- Buy the tokens held in this contract, at the price per token set by the sender, until the claiming period end timestamp.
- Lock their vesting contract such that no more Nouns can be sent to it.
