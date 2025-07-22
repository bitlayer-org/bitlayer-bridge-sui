import { bcs, fromHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config, MessageType } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { ethers } from 'ethers'

export const updateFeeRecipient = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')

  tx.moveCall({
    target: `${config.package()}::bridge::update_fee_recipient`,
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap()),
      tx.pure.address("0x9c4d23fa4891160c6a734487d0df87919a7daaa926e65ed577887e0cd55054ef")
    ],
  })

  // const result = await suiClient.devInspectTransactionBlock({
  //   transactionBlock: tx,
  //   sender: keypair.getPublicKey().toSuiAddress(),
  // })
  tx.setGasBudget(13299524)
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })
  console.log('res:', result)
  // console.log('res:', result.results[0].mutableReferenceOutputs)
}
