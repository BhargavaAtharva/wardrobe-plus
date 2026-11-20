import os
import sqlite3
import sys

import pytest
from flask import Flask, jsonify

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import accounts  # noqa: E402


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(accounts, 'DB_PATH', str(tmp_path / 'accounts.db'))
    accounts.init_db()
    accounts.ensure_demo_account()
    app = Flask(__name__)
    app.register_blueprint(accounts.bp)

    @app.route('/private')
    @accounts.require_auth
    def private():
        return jsonify({'email': accounts.g.user['email']})

    return app.test_client()


def register(client, email='a@b.com', password='secret1', name='Ath'):
    return client.post('/auth/register', json={'email': email, 'password': password, 'name': name})


def test_register_then_login(client):
    r = register(client)
    assert r.status_code == 201 and r.json['user']['email'] == 'a@b.com'
    r = client.post('/auth/login', json={'email': ' A@B.com ', 'password': 'secret1'})
    assert r.status_code == 200 and r.json['token']


def test_wrong_password_and_unknown_email(client):
    register(client)
    assert client.post('/auth/login', json={'email': 'a@b.com', 'password': 'nope123'}).status_code == 401
    assert client.post('/auth/login', json={'email': 'x@y.com', 'password': 'secret1'}).status_code == 401


def test_duplicate_email_is_rejected(client):
    register(client)
    r = register(client, email='A@b.com')
    assert r.status_code == 409 and r.json['error'] == 'email_taken'


@pytest.mark.parametrize('email,password,name,error', [
    ('not-an-email', 'secret1', 'Ath', 'bad_email'),
    ('a@b.com', '123', 'Ath', 'weak_password'),
    ('a@b.com', 'secret1', '  ', 'no_name'),
])
def test_register_validation(client, email, password, name, error):
    r = register(client, email, password, name)
    assert r.status_code == 400 and r.json['error'] == error


def test_password_is_not_stored_in_plain_text(client):
    register(client)
    with sqlite3.connect(accounts.DB_PATH) as conn:
        stored = conn.execute("SELECT password_hash FROM users WHERE email='a@b.com'").fetchone()[0]
    assert 'secret1' not in stored


def test_protected_endpoint_needs_a_valid_token(client):
    assert client.get('/private').status_code == 401
    assert client.get('/private', headers={'Authorization': 'Bearer junk'}).status_code == 401
    token = register(client).json['token']
    r = client.get('/private', headers={'Authorization': f'Bearer {token}'})
    assert r.status_code == 200 and r.json['email'] == 'a@b.com'


def test_logout_invalidates_the_token(client):
    token = register(client).json['token']
    client.post('/auth/logout', headers={'Authorization': f'Bearer {token}'})
    assert client.get('/auth/me', headers={'Authorization': f'Bearer {token}'}).status_code == 401


def test_demo_account_exists(client):
    r = client.post('/auth/login', json={'email': accounts.DEMO_EMAIL, 'password': accounts.DEMO_PASSWORD})
    assert r.status_code == 200 and r.json['user']['name'] == 'Demo'
