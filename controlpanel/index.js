// app.js
const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const backupFolder = '/srv/palworld/backup';

function listBackups(folder) {
    const subfolders = [];
    const immediateSubfolders = fs.readdirSync(folder, { withFileTypes: true })
        .filter(item => item.isDirectory())
	.sort((a, b) => {
            const order = ['15min', 'hourly', 'daily', 'weekly'];
            return order.indexOf(a.name) - order.indexOf(b.name);
        })
        .map(item => path.join(folder, item.name));
    for (const subfolder of immediateSubfolders) {
        const subSubfolders = fs.readdirSync(subfolder, { withFileTypes: true })
            .filter(item => item.isDirectory())
            .sort()
            .reverse()
            .map(item => path.join(subfolder, item.name));
        subfolders.push(...subSubfolders.map(subSubfolder => path.relative(folder, subSubfolder)));
    }
    return subfolders;
}

function rollback(backup) {
    executeScript(`/srv/palworld/restore.sh "${backupFolder}/${backup}/./"`);
}

function restart() {
    executeScript(`/srv/palworld/restart.sh`);
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
    const backups = listBackups(backupFolder);
    res.json(backups);
});

app.post('/rollback', (req, res) => {
    const backup = req.body.backup;
    if (!validateBackupString(backup)) {
        return res.status(400).send('Invalid request');
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

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

