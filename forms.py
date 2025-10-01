from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, IntegerField, SelectField, SelectMultipleField, PasswordField, BooleanField, SubmitField
from wtforms.validators import DataRequired, Length, NumberRange
from flask_wtf.file import FileField, FileAllowed

class LoginForm(FlaskForm):
    login = StringField('Логин', validators=[DataRequired()])
    password = PasswordField('Пароль', validators=[DataRequired()])
    remember_me = BooleanField('Запомнить меня')
    submit = SubmitField('Войти')

class BookForm(FlaskForm):
    title = StringField('Название', validators=[DataRequired(), Length(max=255)])
    description = TextAreaField('Описание', validators=[DataRequired()])
    year = IntegerField('Год', validators=[DataRequired(), NumberRange(min=1000, max=2100)])
    publisher = StringField('Издательство', validators=[DataRequired(), Length(max=255)])
    author = StringField('Автор', validators=[DataRequired(), Length(max=255)])
    pages = IntegerField('Количество страниц', validators=[DataRequired(), NumberRange(min=1)])
    genres = SelectMultipleField('Жанры', coerce=int)
    cover = FileField('Обложка', validators=[FileAllowed(['jpg', 'jpeg', 'png', 'gif'], 'Только изображения!')])
    submit = SubmitField('Сохранить')

class ReviewForm(FlaskForm):
    rating = SelectField('Оценка', choices=[
        (5, '5 – отлично'),
        (4, '4 – хорошо'),
        (3, '3 – удовлетворительно'),
        (2, '2 – неудовлетворительно'),
        (1, '1 – плохо'),
        (0, '0 – ужасно')
    ], coerce=int, default=5)
    text = TextAreaField('Текст рецензии', validators=[DataRequired()])
    submit = SubmitField('Сохранить')

class CollectionForm(FlaskForm):
    name = StringField('Название подборки', validators=[DataRequired(), Length(max=255)])