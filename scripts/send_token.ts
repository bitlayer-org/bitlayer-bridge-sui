import { bcs, fromHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { SuiClient } from '@mysten/sui/dist/cjs/client'

export const sendToken = async (suiClient: SuiClient, tx: Transaction) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')

  let target_address = fromHex(process.env.EVM_USER_ADDRESS || '')
  let target_chain = 250
  let token_type = 88
  let token = process.env.TOKEN_OBJECT_ID || ''

  tx.moveCall({
    target: `${config.package()}::bridge::send_token`,
    typeArguments: [config.sbtc_coin_type()],
    arguments: [
      tx.object(config.bridge()),
      tx.pure.u8(target_chain),
      tx.pure.u8(token_type),
      bcs.vector(bcs.u8()).serialize(target_address),
      tx.object(token),
    ],
  })

  //   const result = await suiClient.devInspectTransactionBlock({
  //     transactionBlock: tx,
  //     sender: keypair.getPublicKey().toSuiAddress(),
  //   })
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })
  console.log('res:', result)
  // console.log('res:', result.results[0].mutableReferenceOutputs)
}
