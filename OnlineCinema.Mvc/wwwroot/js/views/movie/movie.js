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
    const movieIdElement = document.getElementById('movie-id');
    if (!movieIdElement) return;
    const dateButtons = document.querySelectorAll('.session-date');
    const hallButtons = document.querySelectorAll('[data-hall-id]');
    const allHallsButton = document.getElementById('btn-all-halls');
    const refresh = () => {
        const date = document.querySelector('.session-date.active')?.dataset.date;
        if (!date) {
            showSessionsMessage('Для этого фильма пока нет предстоящих сеансов.');
            return;
        }
        handleSessionsUpdate({
            movieId: Number(movieIdElement.value), date,
            hallId: document.querySelector('[data-hall-id].active')?.dataset.hallId
        });
    };
    dateButtons.forEach(button => button.addEventListener('click', () => {
        dateButtons.forEach(item => { item.classList.remove('active'); item.setAttribute('aria-pressed', 'false'); });
        button.classList.add('active');
        button.setAttribute('aria-pressed', 'true');
        refresh();
    }));
    hallButtons.forEach(button => button.addEventListener('click', () => {
        hallButtons.forEach(item => { item.classList.remove('active'); item.setAttribute('aria-pressed', 'false'); });
        allHallsButton.classList.remove('active');
        allHallsButton.setAttribute('aria-pressed', 'false');
        button.classList.add('active');
        button.setAttribute('aria-pressed', 'true');
        refresh();
    }));
    allHallsButton.addEventListener('click', () => {
        hallButtons.forEach(item => { item.classList.remove('active'); item.setAttribute('aria-pressed', 'false'); });
        allHallsButton.classList.add('active');
        allHallsButton.setAttribute('aria-pressed', 'true');
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
        card.className = 'session-card';
        const time = document.createElement('a');
        time.className = 'btn btn-primary';
        time.href = `/orders/${session.id}`;
        time.setAttribute('aria-label', `Купить билет на ${session.dateStart.slice(11,16)}, ${session.hallName}`);
        // Местное время кинотеатра без смещения не переводим в часовой пояс браузера.
        time.textContent = `Купить билет · ${session.dateStart.slice(11, 16)}`;
        const hall = document.createElement('p');
        hall.className = 'mb-1';
        hall.textContent = session.hallName;
        const price = document.createElement('p');
        price.textContent = `${session.price} ₽`;
        card.append(time, hall, price);
        container.append(card);
    });
}
