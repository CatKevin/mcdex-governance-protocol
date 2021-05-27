const blessed = require('blessed');

async function main() {
    const screen = blessed.screen({
        smartCSR: true
    });

    let box = blessed.box({
        parent: screen,
        top: 0,
        left: 0,
        width: '80%',
        height: '80%',
        style: {
            bg: 'red'
        },
        keys: true,
        vi: true,
        alwaysScroll: true,
        scrollable: true,
        scrollbar: {
            style: {
                bg: 'yellow'
            }
        }
    });

    screen.render();

    for (let i = 0; i < 200; i++) {
        box.insertLine(0, 'texting ' + i);
        box.screen.render();
    }
}

main().then()