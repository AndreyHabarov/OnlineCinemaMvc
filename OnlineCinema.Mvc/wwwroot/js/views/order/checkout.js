document.addEventListener('DOMContentLoaded', () => {
    const checkoutElement = document.getElementById('checkout');
    const purchaseForm = document.getElementById('purchase-form');
    if (!checkoutElement || !purchaseForm) return;
    const seatButtons = Array.from(document.querySelectorAll('[data-seat-id]'));
    const availableSeatButtons = seatButtons.filter(button => !button.disabled);
    const selectedSeats = new Set();
    const requestId = crypto.randomUUID();
    const purchaseButton = document.getElementById('purchase-button');
    const purchaseErrorElement = document.getElementById('purchase-error');
    let isPurchasePending = false;
    const updateSelectionSummary = () => {
        document.getElementById('selected-seats').textContent = selectedSeats.size
            ? Array.from(selectedSeats).map(button => `ряд ${button.dataset.row}, место ${button.dataset.number}`).join('; ')
            : 'Места не выбраны.';
        const total = Array.from(selectedSeats).reduce((sum, button) => sum + Number(button.dataset.price), 0);
        document.getElementById('order-total').textContent = `${total} ₽`;
        purchaseButton.disabled = isPurchasePending || !selectedSeats.size;
    };
    availableSeatButtons.forEach(button => button.addEventListener('click', () => {
        if (isPurchasePending) return;
        if (selectedSeats.has(button)) selectedSeats.delete(button);
        else if (selectedSeats.size < 6) selectedSeats.add(button);
        else { purchaseErrorElement.textContent = 'В одном заказе можно выбрать не больше 6 мест.'; return; }
        purchaseErrorElement.textContent = '';
        button.classList.toggle('is-selected', selectedSeats.has(button));
        button.setAttribute('aria-pressed', String(selectedSeats.has(button)));
        updateSelectionSummary();
    }));
    document.getElementById('refresh-seats').addEventListener('click', () => window.location.reload());
    purchaseForm.addEventListener('submit', async event => {
        event.preventDefault();
        if (isPurchasePending || !selectedSeats.size) return;
        isPurchasePending = true;
        availableSeatButtons.forEach(button => button.disabled = true);
        document.getElementById('viewer-age').disabled = true;
        document.getElementById('refresh-seats').disabled = true;
        purchaseErrorElement.textContent = '';
        updateSelectionSummary();
        try {
            const {data} = await axios.post('/orders/purchase', {
                requestId, sessionId: Number(checkoutElement.dataset.sessionId),
                seatIds: Array.from(selectedSeats).map(button => Number(button.dataset.seatId)).sort((a,b) => a-b),
                viewerAge: Number(document.getElementById('viewer-age').value)
            });
            window.location.assign(data.receiptUrl);
        } catch (failure) {
            purchaseErrorElement.textContent = failure.response?.data?.message || 'Не удалось получить подтверждение. Повторите запрос с теми же местами.';
        } finally {
            isPurchasePending = false;
            availableSeatButtons.forEach(button => button.disabled = false);
            document.getElementById('viewer-age').disabled = false;
            document.getElementById('refresh-seats').disabled = false;
            updateSelectionSummary();
        }
    });
});
