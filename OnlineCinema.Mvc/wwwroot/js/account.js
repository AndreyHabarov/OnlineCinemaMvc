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
    const modalElement = document.getElementById('PersonalAccountModal');
    if (!modalElement) return;
    const field = id => document.getElementById(id);
    const showError = (id, error) => {
        const data = error.response?.data;
        field(id).textContent = Array.isArray(data?.errors) && data.errors.length
            ? data.errors.join(' ') : data?.message || 'Не удалось выполнить действие. Повторите попытку.';
    };
    const phoneInput = field('PhoneRegistration');
    if (phoneInput && typeof IMask !== 'undefined') IMask(phoneInput, { mask: '+{7}(000)000-00-00' });
    field('EmailBtn').addEventListener('click', () => {
        field('EmailWrapper').classList.remove('d-none');
        field('PhoneWrapper').classList.add('d-none');
        field('Phone').value = '';
        field('LoginError').textContent = '';
    });
    field('PhoneBtn').addEventListener('click', () => {
        field('PhoneWrapper').classList.remove('d-none');
        field('EmailWrapper').classList.add('d-none');
        field('Email').value = '';
        field('LoginError').textContent = '';
    });
    field('LoginButton').addEventListener('click', async event => {
        const button = event.currentTarget;
        button.disabled = true;
        field('LoginError').textContent = '';
        try {
            await axios.post('/Account/Login', {
                email: field('Email').value.trim() || null,
                phone: field('Phone').value.trim() || null,
                password: field('Password').value,
                rememberMe: field('FlexCheckIndeterminate').checked
            });
            const returnUrl = new URLSearchParams(window.location.search).get('returnUrl');
            const destination = returnUrl && returnUrl.startsWith('/') && !returnUrl.startsWith('//') && !returnUrl.includes('\\')
                ? returnUrl : '/lk';
            // Полная загрузка обновляет состояние входа и CSRF-токен для пользователя.
            window.location.assign(destination);
        } catch (error) {
            showError('LoginError', error);
        } finally {
            button.disabled = false;
        }
    });
    field('RegistrationButton').addEventListener('click', async event => {
        const button = event.currentTarget;
        button.disabled = true;
        field('RegistrationError').textContent = '';
        try {
            const email = field('EmailRegistration').value.trim();
            await axios.post('/Account/Register', {
                name: field('NameRegistration').value.trim(),
                lastName: field('SurnameRegistration').value.trim(),
                phoneNumber: field('PhoneRegistration').value,
                email,
                password: field('EnterPassword').value,
                confirmPassword: field('RepeatPassword').value,
                isMan: field('GenderRegistration').value === 'male'
            });
            field('EnterPassword').value = '';
            field('RepeatPassword').value = '';
            field('LoginTab').click();
            field('EmailBtn').click();
            field('Email').value = email;
            field('LoginError').textContent = 'Регистрация завершена. Теперь войдите в аккаунт.';
        } catch (error) {
            showError('RegistrationError', error);
        } finally {
            button.disabled = false;
        }
    });
    if (new URLSearchParams(window.location.search).get('login') === 'True' ||
        new URLSearchParams(window.location.search).get('login') === 'true') {
        bootstrap.Modal.getOrCreateInstance(modalElement).show();
    }
});
