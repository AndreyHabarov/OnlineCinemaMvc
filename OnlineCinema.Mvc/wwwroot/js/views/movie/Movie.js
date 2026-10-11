let sessionsRequestNumber = 0;

async function handleSessionsUpdate(input) {
    const requestNumber = ++sessionsRequestNumber;
    const container = document.getElementById('sessions-container');
    container.setAttribute('aria-busy', 'true');
    showSessionsMessage('Загрузка сеансов…');
    try {
        const response = await axios.get('/Movies/GetAllSessions', { params: input });
        if (requestNumber !== sessionsRequestNumber) return;
        updateSessions(response.data);
    } catch (error) {
        if (requestNumber !== sessionsRequestNumber) return;
        showSessionsMessage(error.response?.data?.message || 'Не удалось загрузить сеансы. Попробуйте выбрать дату ещё раз.');
    } finally {
        if (requestNumber === sessionsRequestNumber) container.setAttribute('aria-busy', 'false');
    }
}

function showSessionsMessage(message) {
    const container = document.getElementById('sessions-container');
    const paragraph = document.createElement('p');
    paragraph.textContent = message;
    container.replaceChildren(paragraph);
}

document.addEventListener('DOMContentLoaded', () => {
    const movieIdElement = document.getElementById('MovieId');
    if (!movieIdElement) return;
    const dateButtons = document.querySelectorAll('.movie__session__btn');
    const hallButtons = document.querySelectorAll('.hall__other__btn');
    const allHallsButton = document.getElementById('btnAllHalls');
    const refresh = () => {
        const date = document.querySelector('.movie__session__btn.active')?.dataset.date;
        if (!date) {
            showSessionsMessage('Для этого фильма пока нет предстоящих сеансов.');
            return;
        }
        handleSessionsUpdate({
            movieId: Number(movieIdElement.value), date,
            hallId: document.querySelector('.hall__other__btn.active')?.dataset.hallId
        });
    };
    dateButtons.forEach(button => button.addEventListener('click', () => {
        dateButtons.forEach(item => item.classList.remove('active'));
        button.classList.add('active');
        refresh();
    }));
    hallButtons.forEach(button => button.addEventListener('click', () => {
        hallButtons.forEach(item => item.classList.remove('active'));
        allHallsButton.classList.remove('active');
        button.classList.add('active');
        refresh();
    }));
    allHallsButton.addEventListener('click', () => {
        hallButtons.forEach(item => item.classList.remove('active'));
        allHallsButton.classList.add('active');
        refresh();
    });
    refresh();
});

function updateSessions(sessions) {
    if (!sessions.length) {
        showSessionsMessage('На выбранную дату в этом зале нет предстоящих сеансов.');
        return;
    }
    const container = document.getElementById('sessions-container');
    container.replaceChildren();
    sessions.forEach(session => {
        const card = document.createElement('div');
        card.className = 'col-auto ms-2 mb-3';
        const time = document.createElement('a');
        time.className = 'btn btn-outline-primary px-3 py-2 mb-1';
        time.href = `/orders/${session.id}`;
        time.setAttribute('aria-label', `Купить билет на ${session.dateStart.slice(11,16)}, ${session.hallName}`);
        // Местное время кинотеатра без смещения не переводим в часовой пояс браузера.
        time.textContent = session.dateStart.slice(11, 16);
        const hall = document.createElement('p');
        hall.className = 'mb-1';
        hall.textContent = session.hallName;
        const price = document.createElement('p');
        price.textContent = `${session.price} ₽`;
        card.append(time, hall, price);
        container.append(card);
    });
}
