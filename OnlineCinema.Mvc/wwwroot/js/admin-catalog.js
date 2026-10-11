document.addEventListener('DOMContentLoaded', () => {
    const kind = document.getElementById('AdminCatalog').dataset.kind;
    const promotion = kind === 'promotions';
    const base = `/Admin/${kind}`;
    const form = document.getElementById('CatalogForm');
    const modal = bootstrap.Modal.getOrCreateInstance(document.getElementById('CatalogModal'));
    const errorText = error => error.response?.data?.message || 'Не удалось выполнить действие. Повторите попытку.';
    const columns = [{ data: promotion ? 'displayName' : 'name', render: DataTable.render.text(), orderable: false }];
    if (promotion) columns.push({ data: 'dateTime', orderable: false, render: value => dayjs(value).format('DD.MM.YYYY') });
    columns.push({ data: 'id', orderable: false, searchable: false, render: id => `<button class="btn btn-sm btn-outline-primary" data-edit="${Number(id)}">Изменить</button> <button class="btn btn-sm btn-outline-danger" data-delete="${Number(id)}">Удалить</button>` });
    const table = new DataTable('#CatalogTable', {
        serverSide: true, ordering: false, columns,
        language: { search: 'Поиск:', lengthMenu: 'Показывать _MENU_', info: '_START_–_END_ из _TOTAL_', infoEmpty: 'Записей нет', emptyTable: 'Записей нет', zeroRecords: 'Ничего не найдено', paginate: { previous: 'Назад', next: 'Далее', first: 'Первая', last: 'Последняя' } },
        ajax: async (request, callback) => {
            try {
                const { data } = await axios.post(`${base}/GetAll`, { skipCount: request.start, pageSize: request.length, keyword: request.search.value });
                document.getElementById('CatalogError').textContent = '';
                callback({ draw: request.draw, recordsTotal: data.totalCount, recordsFiltered: data.filteredCount, data: data.items });
            } catch (error) {
                document.getElementById('CatalogError').textContent = errorText(error);
                callback({ draw: request.draw, recordsTotal: 0, recordsFiltered: 0, data: [] });
            }
        }
    });
    const open = data => {
        form.reset();
        document.getElementById('CatalogFormError').textContent = '';
        document.getElementById('CatalogTitle').textContent = data ? 'Редактирование' : 'Добавление';
        for (const input of form.elements) {
            if (!input.name || input.type === 'file') continue;
            const property = input.name.charAt(0).toLowerCase() + input.name.slice(1);
            input.value = data?.[property] ?? (input.name === 'Id' ? '0' : '');
            if (input.type === 'date') input.value = data?.[property]?.slice(0,10) || dayjs().format('YYYY-MM-DD');
        }
        if (promotion) {
            const preview = document.getElementById('CatalogPreview');
            preview.hidden = !data?.imagePath;
            if (data?.imagePath) preview.src = '/' + data.imagePath.replace(/^\/+/, '');
            form.elements.Image.required = !data;
        }
        modal.show();
    };
    document.getElementById('CatalogAdd').addEventListener('click', () => open(null));
    document.getElementById('CatalogTable').addEventListener('click', async event => {
        const edit = event.target.closest('[data-edit]');
        const remove = event.target.closest('[data-delete]');
        try {
            if (edit) { const {data} = await axios.get(`${base}/Get?id=${edit.dataset.edit}`); open(data); }
            if (remove) {
                const confirmation = await Swal.fire({ title: 'Удалить запись?', text: 'Это действие удалит выбранную запись.', icon: 'warning', showCancelButton: true, confirmButtonText: 'Удалить', cancelButtonText: 'Отмена' });
                if (confirmation.isConfirmed) { await axios.delete(`${base}/Delete?id=${remove.dataset.delete}`); table.ajax.reload(null, false); }
            }
        } catch (error) { document.getElementById('CatalogError').textContent = errorText(error); }
    });
    form.addEventListener('submit', async event => {
        event.preventDefault();
        const button = document.getElementById('CatalogSave');
        if (button.disabled) return;
        button.disabled = true;
        const id = Number(form.elements.Id.value);
        try {
            const data = promotion ? new FormData(form) : { id, name: form.elements.Name.value };
            if (promotion && !form.elements.Image.files.length) data.delete('Image');
            await axios({ url: `${base}/${id ? 'Update' : 'Create'}`, method: id ? 'put' : 'post', data });
            modal.hide();
            table.ajax.reload(null, false);
        } catch (error) { document.getElementById('CatalogFormError').textContent = errorText(error); }
        finally { button.disabled = false; }
    });
});
