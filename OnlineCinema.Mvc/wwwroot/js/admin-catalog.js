document.addEventListener('DOMContentLoaded', () => {
    const kind = document.getElementById('admin-catalog').dataset.kind;
    const isPromotionCatalog = kind === 'promotions';
    const catalogBaseUrl = `/Admin/${kind}`;
    const catalogForm = document.getElementById('catalog-form');
    const catalogModal = bootstrap.Modal.getOrCreateInstance(document.getElementById('catalog-modal'));
    const getErrorMessage = error => error.response?.data?.message || 'Не удалось выполнить действие. Повторите попытку.';
    const columns = [{ data: isPromotionCatalog ? 'displayName' : 'name', render: DataTable.render.text(), orderable: false }];
    if (isPromotionCatalog) columns.push({ data: 'dateTime', orderable: false, render: value => dayjs(value).format('DD.MM.YYYY') });
    columns.push({ data: 'id', orderable: false, searchable: false, render: id => `<button class="btn btn-sm btn-outline-primary" data-edit="${Number(id)}">Изменить</button> <button class="btn btn-sm btn-outline-danger" data-delete="${Number(id)}">Удалить</button>` });
    const catalogTable = new DataTable('#catalog-table', {
        serverSide: true, ordering: false, columns,
        language: { search: 'Поиск:', lengthMenu: 'Показывать _MENU_', info: '_START_–_END_ из _TOTAL_', infoEmpty: 'Записей нет', infoFiltered: '(из _MAX_ записей)', loadingRecords: 'Загрузка…', processing: 'Обработка…', emptyTable: 'Записей нет', zeroRecords: 'Ничего не найдено', paginate: { previous: 'Назад', next: 'Далее', first: 'Первая', last: 'Последняя' } },
        ajax: async (request, callback) => {
            try {
                const { data } = await axios.post(`${catalogBaseUrl}/GetAll`, { skipCount: request.start, pageSize: request.length, keyword: request.search.value });
                document.getElementById('catalog-error').textContent = '';
                callback({ draw: request.draw, recordsTotal: data.totalCount, recordsFiltered: data.filteredCount, data: data.items });
            } catch (error) {
                document.getElementById('catalog-error').textContent = getErrorMessage(error);
                callback({ draw: request.draw, recordsTotal: 0, recordsFiltered: 0, data: [] });
            }
        }
    });
    const openEditor = data => {
        catalogForm.reset();
        document.getElementById('catalog-form-error').textContent = '';
        document.getElementById('catalog-title').textContent = data ? 'Редактирование' : 'Добавление';
        for (const input of catalogForm.elements) {
            if (!input.name || input.type === 'file') continue;
            const property = input.name.charAt(0).toLowerCase() + input.name.slice(1);
            input.value = data?.[property] ?? (input.name === 'Id' ? '0' : '');
            if (input.type === 'date') input.value = data?.[property]?.slice(0,10) || dayjs().format('YYYY-MM-DD');
        }
        if (isPromotionCatalog) {
            const preview = document.getElementById('catalog-preview');
            preview.hidden = !data?.imagePath;
            if (data?.imagePath) preview.src = '/' + data.imagePath.replace(/^\/+/, '');
            catalogForm.elements.Image.required = !data;
        }
        catalogModal.show();
    };
    document.getElementById('catalog-add').addEventListener('click', () => openEditor(null));
    document.getElementById('catalog-table').addEventListener('click', async event => {
        const edit = event.target.closest('[data-edit]');
        const remove = event.target.closest('[data-delete]');
        try {
            if (edit) { const {data} = await axios.get(`${catalogBaseUrl}/Get?id=${edit.dataset.edit}`); openEditor(data); }
            if (remove) {
                const confirmation = await Swal.fire({ title: 'Удалить запись?', text: 'Это действие удалит выбранную запись.', icon: 'warning', showCancelButton: true, confirmButtonText: 'Удалить', cancelButtonText: 'Отмена' });
                if (confirmation.isConfirmed) { await axios.delete(`${catalogBaseUrl}/Delete?id=${remove.dataset.delete}`); catalogTable.ajax.reload(null, false); }
            }
        } catch (error) { document.getElementById('catalog-error').textContent = getErrorMessage(error); }
    });
    catalogForm.addEventListener('submit', async event => {
        event.preventDefault();
        const button = document.getElementById('catalog-save');
        if (button.disabled) return;
        button.disabled = true;
        const id = Number(catalogForm.elements.Id.value);
        try {
            const data = isPromotionCatalog ? new FormData(catalogForm) : { id, name: catalogForm.elements.Name.value };
            if (isPromotionCatalog && !catalogForm.elements.Image.files.length) data.delete('Image');
            await axios({ url: `${catalogBaseUrl}/${id ? 'Update' : 'Create'}`, method: id ? 'put' : 'post', data });
            catalogModal.hide();
            catalogTable.ajax.reload(null, false);
        } catch (error) { document.getElementById('catalog-form-error').textContent = getErrorMessage(error); }
        finally { button.disabled = false; }
    });
});
