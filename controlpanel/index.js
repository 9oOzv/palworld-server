#!/usr/bin/env node

const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');
const app = express();
const yargs = require('yargs/yargs')

argv = yargs(process.argv.slice(2))
    .option('backups-folder', {
        alias: 'b',
        type: 'string',
        description: 'path to the backup storage',
        default: './backups'
    })
    .option('run-sh', {
        alias: 'r',
        type: 'string',
        description: '`run.sh` location',
        default: './run.sh'
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

function sortBackupInfos(backupInfos) {
    const nameOrder = {
        "15min": 1,
        "hourly": 2,
        "daily": 3,
        "weekly": 4
    };
    function compare(a, b) {
        const [nameA, timestampA] = a.path.split('/');
        const [nameB, timestampB] = b.path.split('/');
        const nameComparison = nameOrder[nameA] - nameOrder[nameB];
        if (nameComparison !== 0) {
            return nameComparison;
        }
        return timestampB < timestampA ? -1 : 1
    }
    return backupInfos.sort(compare);
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

async function rollback(backup) { await executeScript(`${argv.runSh} restore "${argv.backupsFolder}/${backup}/./"`); }
async function start() { await executeScript(`${argv.runSh} start`); }
async function stop() { await executeScript(`${argv.runSh} stop`); }
async function restart() { await executeScript(`${argv.runSh} restart`); }
async function update() { await executeScript(`${argv.runSh} udpate`); }

function executeScript(command) {
    console.error(`Executing: ${command}`);
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error executing: ${error.message}`);
                reject(error);
                return;
            }
            if (stderr) {
                console.error(`Exec stderr: ${stderr}`);
                reject(new Error(stderr));
                return;
            }
            resolve(stdout.trim());
        });
    });
}

function validateBackupString(str) {
    const regex = /^[^\/]+\/backup_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/;
    return regex.test(str);
}

function backupActions() {
    const backupInfos = sortBackupInfos(findBackupsAndSizes(argv.backupsFolder))
    return backupInfos.map(info =>
        ({
            name: 'rollback',
            html: `Rollback: ${info.path.split('\/')[1].padStart(24)} -- <span class="number">${(info.size / 1024 / 1024).toFixed(2).padStart(5,'0')}MB</span>`,
            text: `Rollback to ${info.path.split('\/')[1]} (${(info.size / 1024 / 1024).toFixed(2).padStart(5,'0')}MB)`,
            value: info.path
        })
    );
}

app.use(express.static('public'));

app.use(express.json());

app.get('/actions', (req, res) => {

    actions = [
        { name: 'start', html: 'Start server', text: 'Start server' },
        { name: 'stop', html: 'Stop server', text: 'stop server' },
        { name: 'restart', html: 'Restart server', text: 'Restart server' },
        { name: 'update', html: 'Update server', text: 'Update server' },
        ...backupActions()
    ]
    res.json(actions);
});

app.post('/exec', async (req, res, next) => {
    const action = req.body;
    console.log(`Executing action: ${JSON.stringify(action)}`)
    switch (action.name) {
        case "start":
            await start()
                .then(v =>res.send('Start complete'))
                .catch(err => next(err));
            break;
        case "stop":
            await stop()
                .then(v =>res.send('Stop complete'))
                .catch(err => next(err));
            break;
        case "restart":
            await restart()
                .then(v =>res.send('Restart complete'))
                .catch(err => next(err));
            break;
        case "update":
            await update()
                .then(v =>res.send('Update complete'))
                .catch(err => next(err));
            break;
        case "rollback":
            await rollback(action.value)
                .then(v => res.send('Rollback complete'))
                .catch(err => next(err));
            break;
        default:
            res.send(`Invalid action: ${JSON.stringify(action)}`);
            break;
    }
});

app.listen(argv.port, () => {
    console.log(`Server is running on port ${argv.port}`);
});
