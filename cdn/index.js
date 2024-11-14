/**
 * @Author       : PeiHua
 * @Version      : V1.0
 * @Date         : 2024-11-14 09:26:08
 * @Description  : 
*/
// Import required AWS SDK clients and commands for Node.js.
import { PutObjectCommand } from "@aws-sdk/client-s3"
import { CreateInvalidationCommand } from "@aws-sdk/client-cloudfront"
import { s3Client, cfClient, s3 } from "./libs/client.js" // Helper function that creates an Amazon S3 service client module.
import { join } from "path"
import fs from "fs"
import mime from "mime"

const baseDir = process.env.DATA_PATH || ['../wp/html/wp-content/', '../wp/html/wp-includes/']
const distributionId = process.env.DISTRIBUTION_ID || 'E26EZJCNBKX7UK'

console.log('baseDir', baseDir)

function dirMap(path) {
  return new Promise(async (resolve, reject) => {
    fs.readdir(path, async (err, data) => {
      if (err) {
        console.log('\x1B[31m%s\x1B[0m', 'error: ', err)
        reject(err)
      }

      let allFileMap = []
      for (let i = 0; i < data.length; i++) {
        const target = data[i]
        const _path = join(path, target)
        let stats
        try {
          stats = fs.statSync(_path)
        } catch (err) {
          console.log('\x1B[31m%s\x1B[0m', 'error:', err)
        }

        if (stats.isFile()) {
          // await cb(_path)
          allFileMap.push(_path)
        }

        if (stats.isDirectory()) {
          const fileMap = await dirMap(_path)
          allFileMap = allFileMap.concat(fileMap)
        }
      }

      resolve(allFileMap)
    })
  })
}

async function updateCdn() {
  const paths = ['/index.html']
  const inputCommand = {
    DistributionId: distributionId,
    InvalidationBatch: {
      CallerReference: new Date().getTime(),
      Paths: {
        Items: paths,
        Quantity: paths.length
      }
    }
  }

  const _data = await cfClient.send(new CreateInvalidationCommand(inputCommand))
  if (_data.Invalidation.Id) {
    console.log('\x1B[32m%s\x1B[0m', 'CDN refreshed successfully, task id:', _data.Invalidation.Id)
  }
}

function forSyncWrapper(arr) {
  const fnArr = arr.map(path => new Promise(async function (resolve, reject) {
    let data
    try {
      data = fs.readFileSync(path)
    } catch (err) {
      console.log('Read upload file error:', path)
      reject()
    }
    const key = path.replaceAll(baseDir, '')
    console.log('upload path', key)
    const bucketParams = {
      Bucket: process.env.Bucket || 'wp-cdn-store',
      // Specify the name of the new object. For example, 'index.html'.
      // To create a directory for the object, use '/'. For example, 'myApp/package.json'.
      Key: key,
      // Content of the new object.
      Body: data,
      ContentType: mime.getType(path)
    };

    s3.upload(bucketParams, (err, data) => {
      if (err) {
        console.log('\x1B[31m%s\x1B[0m', 'upload err: ', err)
        reject()
      }
      console.log('\x1B[32m%s\x1B[0m', 'File uploaded successfully: ', path.replaceAll(baseDir, ''))
      resolve()
    })

    // resolve()
  }))
  return Promise.all(fnArr)
}

console.log('\x1B[36m%s\x1B[0m', '=== Start uploading files ===')
if (Array.isArray(baseDir)) {
  for await (let dir of baseDir) {
    dirMap(dir)
      .then(async map => {
        await forSyncWrapper(map)
        console.log('\x1B[36m%s\x1B[0m', `=== Dir ${dir} have been uploaded successfully. ===`)
      })
  }
  updateCdn()
} else {
  dirMap(baseDir)
    .then(async map => {
      await forSyncWrapper(map)
      console.log('\x1B[36m%s\x1B[0m', '=== All files have been uploaded successfully. ===')
      updateCdn()
    })
}