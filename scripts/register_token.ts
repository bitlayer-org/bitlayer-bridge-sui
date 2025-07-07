import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'

export const registerToken = async (suiClient: SuiClient, tx: Transaction) => {
  const keypair = Ed25519Keypair.fromSecretKey(Buffer.from(config.admin(), 'hex') || '')
  tx.moveCall({
    target: `${config.package()}::bridge::register_foreign_token`,
    typeArguments: [config.sbtc_coin_type()],
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.sbtc_treasury()),
      tx.object(config.sbtc_metadata()),
    ],
  })
  // const result = await suiClient.devInspectTransactionBlock({
  //   transactionBlock: tx,
  //   sender: keypair.getPublicKey().toSuiAddress(),
  // })
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })

  console.log('registerToken: ', result)
}
