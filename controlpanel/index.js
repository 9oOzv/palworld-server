#!/usr/bin/env node

const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');
const app = express();
const backupFolder = '/srv/palworld/backup';
const yargs = require('yargs/yargs')

argv = yargs(process.argv.slice(2))
    .option('backups-folder', {
        alias: 'b',
        type: 'string',
        description: 'path to the backup storage',
        default: './backups'
    })
    .option('port', {
        alias: 'p',
        type: 'string',
        description: 'port to bind on',
        default: '3000'
    })
    .parse()

function findBackupsAndSizes(folderPath) {
    let subfolderInfo = [];
    function traverseDirectory(currentPath) {
        const files = fs.readdirSync(currentPath);
        files.forEach(file => {
            const filePath = path.join(currentPath, file);
            const relativePath = path.relative(folderPath, filePath);
            const stats = fs.statSync(filePath);
            if (stats.isDirectory()) {
                const dateRegex = /\d{4}-\d{2}-\d{2}/;
                if (dateRegex.test(file)) {
                    const subfolderSize = getFolderSize(filePath);
                    subfolderInfo.push({
                        path: relativePath,
                        size: subfolderSize
                    });
                }
                traverseDirectory(filePath);
            }
        });
    }
    traverseDirectory(folderPath);
    return subfolderInfo;
}

function getFolderSize(folderPath) {
    let totalSize = 0;
    const files = fs.readdirSync(folderPath);
    files.forEach(file => {
        const filePath = path.join(folderPath, file);
        const stats = fs.statSync(filePath);
        if (stats.isFile()) {
            totalSize += stats.size;
        } else if (stats.isDirectory()) {
            totalSize += getFolderSize(filePath);
        }
    });
    return totalSize;
}

function rollback(backup) {
    executeScript(`/srv/palworld/run.sh restore "${backupFolder}/${backup}/./"`);
}

function restart() {
    executeScript(`/srv/palworld/run.sh restart`);
}

function update() {
    executeScript(`/srv/palworld/run.sh update`);
}

function executeScript(command) {
    console.error(`Executing: ${command}`);
    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing : ${error.message}`);
            return;
        }
        if (stderr) {
            console.error(`Exec stderr: ${stderr}`);
            return;
        }
        console.log(stdout);
    });
}

function validateBackupString(str) {
    const regex = /^[^\/]+\/backup_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/;
    return regex.test(str);
}

app.use(express.static('public'));

app.use(express.json());

app.get('/backups', (req, res) => {
    const backups = findBackupsAndSizes(argv.backupsFolder);
    res.json(backups);
});

app.post('/rollback', (req, res) => {
    const backup = req.body.backup;
    if (!validateBackupString(backup)) {
        return res.status(400).send(`Invalid backup string: ${backup}`);
    }
    if (!backup) {
        return res.status(400).send('No folder selected');
    }
    rollback(backup);
    res.send('Rollback complete');
});

app.post('/restart', (req, res) => {
    restart();
    res.send('Restart complete');
});

app.post('/update', (req, res) => {
    update();
    res.send('Update complete');
});

app.listen(argv.port, () => {
    console.log(`Server is running on port ${argv.port}`);
});
