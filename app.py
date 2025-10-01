from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, abort
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from werkzeug.utils import secure_filename
import os
import hashlib
import bleach
from config import Config
from models import db, User, Book, Genre, Cover, Review, Role, Collection
from forms import LoginForm, BookForm, ReviewForm, CollectionForm

app = Flask(__name__)
app.config.from_object(Config)

db.init_app(app)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
login_manager.login_message = 'Для выполнения данного действия необходимо пройти процедуру аутентификации'

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

def init_db():
    with app.app_context():
        db.create_all()
        
        # Создаем роли
        roles = [
            ('Администратор', 'Суперпользователь, имеет полный доступ к системе'),
            ('Модератор', 'Может редактировать данные книг и производить модерацию рецензий'),
            ('Пользователь', 'Может оставлять рецензии')
        ]
        
        for role_name, description in roles:
            if not Role.query.filter_by(name=role_name).first():
                role = Role(name=role_name, description=description)
                db.session.add(role)
        
        # Создаем администратора
        if not User.query.filter_by(login='admin').first():
            admin_role = Role.query.filter_by(name='Администратор').first()
            admin = User(
                login='admin',
                last_name='Администратор',
                first_name='Система',
                role_id=admin_role.id
            )
            admin.set_password('admin')
            db.session.add(admin)
        
        # Создаем модератора
        if not User.query.filter_by(login='moderator').first():
            moderator_role = Role.query.filter_by(name='Модератор').first()
            moderator = User(
                login='moderator',
                last_name='Модераторов',
                first_name='Иван',
                middle_name='Петрович',
                role_id=moderator_role.id
            )
            moderator.set_password('moderator123')
            db.session.add(moderator)
        
        # Создаем пользователя
        if not User.query.filter_by(login='user1').first():
            user_role = Role.query.filter_by(name='Пользователь').first()
            user1 = User(
                login='user1',
                last_name='Иванов',
                first_name='Алексей',
                middle_name='Сергеевич',
                role_id=user_role.id
            )
            user1.set_password('user123')
            db.session.add(user1)
        
        # Создаем жанры
        genres = ['Художественная литература', 'Научная литература', 'Фантастика', 'Детектив', 'Роман', 'Поэзия']
        for genre_name in genres:
            if not Genre.query.filter_by(name=genre_name).first():
                genre = Genre(name=genre_name)
                db.session.add(genre)
        
        db.session.commit()

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in {'jpg', 'jpeg', 'png', 'gif'}

def save_cover(file, book_id):
    if file and allowed_file(file.filename):
        file_content = file.read()
        md5_hash = hashlib.md5(file_content).hexdigest()
        
        existing_cover = Cover.query.filter_by(md5_hash=md5_hash).first()
        if existing_cover:
            return existing_cover.id
        
        cover = Cover(
            filename=secure_filename(file.filename),
            mime_type=file.mimetype,
            md5_hash=md5_hash,
            book_id=book_id
        )
        db.session.add(cover)
        db.session.flush()
        
        filename = f"{cover.id}.{file.filename.rsplit('.', 1)[1].lower()}"
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
        with open(file_path, 'wb') as f:
            f.write(file_content)
        
        cover.filename = filename
        return cover.id
    return None

def has_permission(required_roles):
    if not current_user.is_authenticated:
        return False
    return current_user.role.name in required_roles

@app.route('/')
def index():
    page = request.args.get('page', 1, type=int)
    books = Book.query.order_by(Book.year.desc()).paginate(
        page=page, per_page=10, error_out=False)
    
    for book in books.items:
        reviews_count = Review.query.filter_by(book_id=book.id).count()
        avg_rating = db.session.query(db.func.avg(Review.rating)).filter_by(book_id=book.id).scalar()
        book.reviews_count = reviews_count
        book.avg_rating = round(avg_rating, 1) if avg_rating else 0
    
    return render_template('index.html', books=books)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('index'))
    
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(login=form.login.data).first()
        if user and user.check_password(form.password.data):
            login_user(user, remember=form.remember_me.data)
            next_page = request.args.get('next')
            return redirect(next_page or url_for('index'))
        flash('Невозможно аутентифицироваться с указанными логином и паролем')
    
    return render_template('login.html', form=form)

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))

@app.route('/book/<int:book_id>')
def book_detail(book_id):
    book = Book.query.get_or_404(book_id)
    reviews = Review.query.filter_by(book_id=book_id).order_by(Review.created_at.desc()).all()
    user_review = None
    user_collections = []
    
    if current_user.is_authenticated:
        user_review = Review.query.filter_by(book_id=book_id, user_id=current_user.id).first()
        if current_user.role.name == 'Пользователь':
            user_collections = Collection.query.filter_by(user_id=current_user.id).all()
    
    return render_template('book_detail.html', book=book, reviews=reviews, 
                          user_review=user_review, user_collections=user_collections)

@app.route('/book/add', methods=['GET', 'POST'])
@login_required
def add_book():
    if not has_permission(['Администратор']):
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    form = BookForm()
    form.genres.choices = [(g.id, g.name) for g in Genre.query.all()]
    
    if form.validate_on_submit():
        try:
            book = Book(
                title=form.title.data,
                description=bleach.clean(form.description.data),
                year=form.year.data,
                publisher=form.publisher.data,
                author=form.author.data,
                pages=form.pages.data
            )
            
            selected_genres = Genre.query.filter(Genre.id.in_(form.genres.data)).all()
            book.genres = selected_genres
            
            db.session.add(book)
            db.session.flush()
            
            if form.cover.data:
                save_cover(form.cover.data, book.id)
            
            db.session.commit()
            flash('Книга успешно добавлена')
            return redirect(url_for('book_detail', book_id=book.id))
            
        except Exception as e:
            db.session.rollback()
            flash('При сохранении данных возникла ошибка. Проверьте корректность введённых данных.')
    
    return render_template('book_form.html', form=form, title='Добавление книги')

@app.route('/book/<int:book_id>/edit', methods=['GET', 'POST'])
@login_required
def edit_book(book_id):
    if not has_permission(['Администратор', 'Модератор']):
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    book = Book.query.get_or_404(book_id)
    form = BookForm(obj=book)
    form.genres.choices = [(g.id, g.name) for g in Genre.query.all()]
    
    if request.method == 'GET':
        form.genres.data = [g.id for g in book.genres]
    
    if form.validate_on_submit():
        try:
            book.title = form.title.data
            book.description = bleach.clean(form.description.data)
            book.year = form.year.data
            book.publisher = form.publisher.data
            book.author = form.author.data
            book.pages = form.pages.data
            
            selected_genres = Genre.query.filter(Genre.id.in_(form.genres.data)).all()
            book.genres = selected_genres
            
            db.session.commit()
            flash('Книга успешно обновлена')
            return redirect(url_for('book_detail', book_id=book.id))
            
        except Exception as e:
            db.session.rollback()
            flash('При сохранении данных возникла ошибка. Проверьте корректность введённых данных.')
    
    return render_template('book_form.html', form=form, title='Редактирование книги', book=book)

@app.route('/book/<int:book_id>/delete', methods=['POST'])
@login_required
def delete_book(book_id):
    if not has_permission(['Администратор']):
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    book = Book.query.get_or_404(book_id)
    
    try:
        for cover in book.covers:
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], cover.filename)
            if os.path.exists(file_path):
                os.remove(file_path)
        
        db.session.delete(book)
        db.session.commit()
        flash('Книга успешно удалена')
    except Exception as e:
        db.session.rollback()
        flash('При удалении книги возникла ошибка')
    
    return redirect(url_for('index'))

@app.route('/book/<int:book_id>/review', methods=['GET', 'POST'])
@login_required
def add_review(book_id):
    if not has_permission(['Пользователь', 'Модератор', 'Администратор']):
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    book = Book.query.get_or_404(book_id)
    
    existing_review = Review.query.filter_by(book_id=book_id, user_id=current_user.id).first()
    if existing_review:
        flash('Вы уже оставляли рецензию на эту книгу')
        return redirect(url_for('book_detail', book_id=book_id))
    
    form = ReviewForm()
    
    if form.validate_on_submit():
        try:
            review = Review(
                book_id=book_id,
                user_id=current_user.id,
                rating=form.rating.data,
                text=bleach.clean(form.text.data)
            )
            
            db.session.add(review)
            db.session.commit()
            flash('Рецензия успешно добавлена')
            return redirect(url_for('book_detail', book_id=book_id))
            
        except Exception as e:
            db.session.rollback()
            flash('При сохранении рецензии возникла ошибка')
    
    return render_template('review_form.html', form=form, book=book)

# НОВЫЙ МАРШРУТ: Удаление рецензии (для модераторов и администраторов)
@app.route('/review/<int:review_id>/delete', methods=['POST'])
@login_required
def delete_review(review_id):
    if not has_permission(['Модератор', 'Администратор']):
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    review = Review.query.get_or_404(review_id)
    book_id = review.book_id
    
    try:
        db.session.delete(review)
        db.session.commit()
        flash('Рецензия успешно удалена')
    except Exception as e:
        db.session.rollback()
        flash('При удалении рецензии возникла ошибка')
    
    return redirect(url_for('book_detail', book_id=book_id))

# НОВЫЙ МАРШРУТ: Страница управления рецензиями для модераторов
@app.route('/moderation/reviews')
@login_required
def moderation_reviews():
    if not has_permission(['Модератор', 'Администратор']):
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    page = request.args.get('page', 1, type=int)
    reviews = Review.query.order_by(Review.created_at.desc()).paginate(
        page=page, per_page=20, error_out=False)
    
    return render_template('moderation_reviews.html', reviews=reviews)

@app.route('/collections')
@login_required
def collections():
    if current_user.role.name != 'Пользователь':
        flash('У вас недостаточно прав для выполнения данного действия')
        return redirect(url_for('index'))
    
    user_collections = Collection.query.filter_by(user_id=current_user.id).all()
    
    for collection in user_collections:
        collection.books_count = len(collection.books)
    
    return render_template('collections.html', collections=user_collections)

@app.route('/collections/add', methods=['POST'])
@login_required
def add_collection():
    if current_user.role.name != 'Пользователь':
        return jsonify({'success': False, 'message': 'Недостаточно прав'})
    
    name = request.json.get('name')
    if not name:
        return jsonify({'success': False, 'message': 'Название не может быть пустым'})
    
    try:
        collection = Collection(name=name, user_id=current_user.id)
        db.session.add(collection)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Подборка успешно создана'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Ошибка при создании подборки'})

@app.route('/collections/<int:collection_id>')
@login_required
def collection_detail(collection_id):
    collection = Collection.query.get_or_404(collection_id)
    
    if collection.user_id != current_user.id and current_user.role.name != 'Администратор':
        flash('У вас нет доступа к этой подборке')
        return redirect(url_for('collections'))
    
    return render_template('collection_detail.html', collection=collection)

@app.route('/collections/<int:collection_id>/add_book', methods=['POST'])
@login_required
def add_book_to_collection(collection_id):
    collection = Collection.query.get_or_404(collection_id)
    
    if collection.user_id != current_user.id:
        return jsonify({'success': False, 'message': 'Недостаточно прав'})
    
    book_id = request.json.get('book_id')
    book = Book.query.get_or_404(book_id)
    
    try:
        if book in collection.books:
            return jsonify({'success': False, 'message': 'Книга уже в подборке'})
        
        collection.books.append(book)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Книга успешно добавлена в подборку'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Ошибка при добавлении книги'})

if __name__ == '__main__':
    init_db()
    app.run(debug=True)