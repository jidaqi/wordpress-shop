/**
 * @Author       : PeiHua
 * @Version      : V1.0
 * @Date         : 2024-11-14 09:32:54
 * @Description  : 
*/
// Create service client module using ES6 syntax.
import { S3Client } from "@aws-sdk/client-s3"
import { CloudFront } from "@aws-sdk/client-cloudfront"
import AWS from 'aws-sdk'
import config from './secret_config.js'

const REGION = process.env.REGION
const credentials = config
AWS.config.update({ region: REGION })

// Set the AWS Region.
// Create an Amazon S3 service client object.
const s3Client = new S3Client({ region: REGION, credentials })
const cfClient = new CloudFront({ region: REGION, credentials })
const s3 = new AWS.S3(credentials)
export { s3Client, cfClient, s3 }