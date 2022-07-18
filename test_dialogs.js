const dialogReq = require('.');

const dialog = new dialogReq.Dialog();

dialog.setOptions({
    height: 300,
    width: 400,
    icon: "info",
    okLabel: "Ados",
    cancelLabel: "Utzi"
});

const question = () => dialog.question('title', 'oeoeoe').then(ok => {
    (ok) ? console.log('BAI') : console.log('EZ');
    selectFile();
});

const selectFile = () => dialog.selectFile('hartzu hutsuneekin', true, true).then(resp => {
    console.log('selectFile.response: ' + resp);
    entry();
});

const entry = () => dialog.entry('hartzu hutsuneekin', "nahi duzuna idatzi", 'placeholder').then(resp => {
    console.log('entry.response: ' + 'erantzuna: ' + resp);
    progress();
});

const progress = () => {
    let p = dialog.progress('ari naiz', 'zenbat?');
    let val = 0;
    let intervalId = setInterval(() => {
        val += 10;
        p.progress(val);
        if (val == 100) {
            clearInterval(intervalId);
            password();
        }

    }, 500);
}

const password = () => dialog.password('sartu pasahitza', 'izena eta pasahitza', true).then(c => {
    console.log('password.response: ' + c);
    color();
});

const color = () => dialog.color('aukeratu kolorea').then(c => {
    console.log('color.response: rgb(' + c.red + ', ' + c.green + ', ' + c.blue + ')');
    calendar();
});

const calendar = () => dialog.calendar('aukeratu eguna', 'testua', 1985, 8, 21, '%Y/%m/%d').then(c => {
    console.log('calendar.response: ' + c);
    list();
});

const list = () => dialog.list('aukeratu eguna', 'testua', 'goiburua', ['bat', 'bi', 'hiru'], true).then(c => {
    console.log('list.response: ' + c);
    dialog.notify('Test', 'akabo proba');
});

question();