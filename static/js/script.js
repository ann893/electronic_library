// Модальные окна для удаления и добавления в подборки
document.addEventListener('DOMContentLoaded', function() {
    // Обработка модального окна добавления подборки
    const addCollectionModal = document.getElementById('addCollectionModal');
    if (addCollectionModal) {
        addCollectionModal.addEventListener('show.bs.modal', function() {
            document.getElementById('collectionName').value = '';
        });
    }
    
    // Обработка добавления подборки
    const addCollectionForm = document.getElementById('addCollectionForm');
    if (addCollectionForm) {
        addCollectionForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const name = document.getElementById('collectionName').value;
            
            fetch('/collections/add', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ name: name })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    location.reload();
                } else {
                    alert(data.message);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('Произошла ошибка при создании подборки');
            });
        });
    }
    
    // Обработка добавления книги в подборку
    const addToCollectionForms = document.querySelectorAll('.add-to-collection-form');
    addToCollectionForms.forEach(form => {
        form.addEventListener('submit', function(e) {
            e.preventDefault();
            const collectionId = this.querySelector('select').value;
            const bookId = this.querySelector('input[name="book_id"]').value;
            
            fetch(`/collections/${collectionId}/add_book`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ book_id: bookId })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    location.reload();
                } else {
                    alert(data.message);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('Произошла ошибка при добавлении книги в подборку');
            });
        });
    });
});