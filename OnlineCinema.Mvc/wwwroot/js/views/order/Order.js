document.addEventListener('DOMContentLoaded', () => {
    const root = document.getElementById('Checkout');
    const form = document.getElementById('PurchaseForm');
    if (!root || !form) return;
    const seats = Array.from(document.querySelectorAll('[data-seat-id]'));
    const available = seats.filter(button => !button.disabled);
    const selected = new Set();
    const requestId = crypto.randomUUID();
    const purchaseButton = document.getElementById('PurchaseButton');
    const error = document.getElementById('PurchaseError');
    let pending = false;
    const refresh = () => {
        document.getElementById('SelectedSeats').textContent = selected.size
            ? Array.from(selected).map(button => `ряд ${button.dataset.row}, место ${button.dataset.number}`).join('; ')
            : 'Места не выбраны.';
        const total = Array.from(selected).reduce((sum, button) => sum + Number(button.dataset.price), 0);
        document.getElementById('OrderTotal').textContent = `${total} ₽`;
        purchaseButton.disabled = pending || !selected.size;
    };
    available.forEach(button => button.addEventListener('click', () => {
        if (pending) return;
        if (selected.has(button)) selected.delete(button);
        else if (selected.size < 6) selected.add(button);
        else { error.textContent = 'В одном заказе можно выбрать не больше 6 мест.'; return; }
        error.textContent = '';
        button.classList.toggle('selected', selected.has(button));
        button.setAttribute('aria-pressed', String(selected.has(button)));
        refresh();
    }));
    document.getElementById('RefreshSeats').addEventListener('click', () => window.location.reload());
    form.addEventListener('submit', async event => {
        event.preventDefault();
        if (pending || !selected.size) return;
        pending = true;
        available.forEach(button => button.disabled = true);
        document.getElementById('ViewerAge').disabled = true;
        document.getElementById('RefreshSeats').disabled = true;
        error.textContent = '';
        refresh();
        try {
            const {data} = await axios.post('/orders/purchase', {
                requestId, sessionId: Number(root.dataset.sessionId),
                seatIds: Array.from(selected).map(button => Number(button.dataset.seatId)).sort((a,b) => a-b),
                viewerAge: Number(document.getElementById('ViewerAge').value)
            });
            window.location.assign(data.receiptUrl);
        } catch (failure) {
            error.textContent = failure.response?.data?.message || 'Не удалось получить подтверждение. Повторите запрос с теми же местами.';
        } finally {
            pending = false;
            available.forEach(button => button.disabled = false);
            document.getElementById('ViewerAge').disabled = false;
            document.getElementById('RefreshSeats').disabled = false;
            refresh();
        }
    });
});
