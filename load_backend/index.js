const folder = "LA_Fire";
const mainFile = "Manual.pdf";
const name = "LA Fire Full"
const bucket = 'gs://spike-pdf-links.appspot.com';




var admin = require("firebase-admin");

var serviceAccount = require("./admin-credentials.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://spike-pdf-links.firebaseio.com"
});

var storage = admin.storage();
var db = admin.firestore()
var docs = [];

async function main() {
    var files = await storage.bucket(bucket).getFiles({directory: folder});
    files[0].forEach((f) => {
        if(f.name.split(folder+"/")[1] != null && f.name.split(folder+"/")[1] != "" && f.name.split(folder+"/")[1][f.name.split(folder+"/")[1].length -1] != "/"){
            docs.push({
                "name" : f.name.split(folder+"/")[1],
                "path" : bucket+"/"+f.name
            });
        }
    });

    var data = {
        "name" : name,
        "rootDoc" : {
            "name" : mainFile,
            "path" : bucket + "/" + folder + "/" + mainFile
        },
        "additionalDocs" : docs
    }

    console.log(JSON.stringify(data));

    var fireDoc = await db.collection("books").doc().set(data);

    console.log(fireDoc);
}

main();