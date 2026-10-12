axios.interceptors.request.use(config => {
    const url = new URL(config.url || '', window.location.origin);
    const method = (config.method || 'get').toLowerCase();
    if (url.origin === window.location.origin && !['get', 'head', 'options'].includes(method)) {
        const token = document.querySelector('input[name="__RequestVerificationToken"]')?.value;
        if (token) config.headers['X-CSRF-TOKEN'] = token;
    }
    return config;
});

document.addEventListener('DOMContentLoaded', () => {
    const modalElement = document.getElementById('personal-account-modal');
    if (!modalElement) return;
    const getFieldElement = id => document.getElementById(id);
    const showError = (id, error) => {
        const data = error.response?.data;
        getFieldElement(id).textContent = Array.isArray(data?.errors) && data.errors.length
            ? data.errors.join(' ') : data?.message || 'Не удалось выполнить действие. Повторите попытку.';
    };
    const phoneInput = getFieldElement('phone-registration');
    if (phoneInput && typeof IMask !== 'undefined') IMask(phoneInput, { mask: '+{7}(000)000-00-00' });
    getFieldElement('email-btn').addEventListener('click', () => {
        getFieldElement('email-wrapper').classList.remove('d-none');
        getFieldElement('phone-wrapper').classList.add('d-none');
        getFieldElement('phone').value = '';
        getFieldElement('login-error').textContent = '';
    });
    getFieldElement('phone-btn').addEventListener('click', () => {
        getFieldElement('phone-wrapper').classList.remove('d-none');
        getFieldElement('email-wrapper').classList.add('d-none');
        getFieldElement('email').value = '';
        getFieldElement('login-error').textContent = '';
    });
    getFieldElement('login-button').addEventListener('click', async event => {
        const button = event.currentTarget;
        button.disabled = true;
        getFieldElement('login-error').textContent = '';
        try {
            await axios.post('/Account/Login', {
                email: getFieldElement('email').value.trim() || null,
                phone: getFieldElement('phone').value.trim() || null,
                password: getFieldElement('password').value,
                rememberMe: getFieldElement('flex-check-indeterminate').checked
            });
            const returnUrl = new URLSearchParams(window.location.search).get('returnUrl');
            const destination = returnUrl && returnUrl.startsWith('/') && !returnUrl.startsWith('//') && !returnUrl.includes('\\')
                ? returnUrl : '/lk';
            // Полная загрузка обновляет состояние входа и CSRF-токен для пользователя.
            window.location.assign(destination);
        } catch (error) {
            showError('login-error', error);
        } finally {
            button.disabled = false;
        }
    });
    getFieldElement('registration-button').addEventListener('click', async event => {
        const button = event.currentTarget;
        button.disabled = true;
        getFieldElement('registration-error').textContent = '';
        try {
            const email = getFieldElement('email-registration').value.trim();
            await axios.post('/Account/Register', {
                name: getFieldElement('name-registration').value.trim(),
                lastName: getFieldElement('surname-registration').value.trim(),
                phoneNumber: getFieldElement('phone-registration').value,
                email,
                password: getFieldElement('enter-password').value,
                confirmPassword: getFieldElement('repeat-password').value,
                isMan: getFieldElement('gender-registration').value === 'male'
            });
            getFieldElement('enter-password').value = '';
            getFieldElement('repeat-password').value = '';
            getFieldElement('login-tab').click();
            getFieldElement('email-btn').click();
            getFieldElement('email').value = email;
            getFieldElement('login-error').textContent = 'Регистрация завершена. Теперь войдите в аккаунт.';
        } catch (error) {
            showError('registration-error', error);
        } finally {
            button.disabled = false;
        }
    });
    if (new URLSearchParams(window.location.search).get('login') === 'True' ||
        new URLSearchParams(window.location.search).get('login') === 'true') {
        bootstrap.Modal.getOrCreateInstance(modalElement).show();
    }
});
