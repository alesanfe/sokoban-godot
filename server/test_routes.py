"""Unit tests de routes.py — sin socket, sin proceso.

La separacion routes/http_api existe exactamente para esto: ejercitar
la logica de dominio del backend llamando `dispatch()` directamente.
python server/test_routes.py
"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# DB temporal antes de importar config (lee SKM_DB al importar)
_tmp = tempfile.mkdtemp()
os.environ["SKM_DB"] = os.path.join(_tmp, "test.db")
os.environ["SKM_ADMINS"] = "boss"

from community import routes, store

BOARD = "#####\n#@$.#\n#####"          # 1 paso 'r' cierra la meta


def req(method, path, body=None, token=None, query=""):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return routes.dispatch(method, path,
                           routes.Req(body=body, headers=h,
                                      query=query, ip="t"))


class RoutesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        store.init_db()

    def test_health(self):
        self.assertEqual(req("GET", "/api/health")[0], 200)

    def test_register_login_feed(self):
        st, b, _ = req("POST", "/api/register",
                       {"username": "alice", "password": "pw1234"})
        self.assertEqual(st, 200)
        tok = b["token"]
        # publish requiere auth
        st, _b, code = req("POST", "/api/publish",
                           {"title": "t", "data": {"board": BOARD}})
        self.assertEqual((st, code), (401, "auth_required"))
        # publish con solucion real -> verified=1
        st, b, _ = req("POST", "/api/publish",
                       {"title": "t", "data": {"board": BOARD},
                        "moves": "r"}, token=tok)
        self.assertEqual((st, b["verified"]), (201, 1))
        eid = b["id"]
        # solucion falsa -> 422 unsolved
        st, _b, code = req("POST", "/api/publish",
                           {"title": "x", "data": {"board": BOARD},
                            "moves": "ll"}, token=tok)
        self.assertEqual((st, code), (422, "unsolved"))
        # feed publico la expone (otros tests tambien publican)
        st, b, _ = req("GET", "/api/feed")
        self.assertEqual(st, 200)
        self.assertIn(eid, [e["id"] for e in b["entries"]])
        # like toggle
        st, b, _ = req("POST", "/api/like", {"id": eid}, token=tok)
        self.assertEqual((st, b["liked"]), (200, True))
        st, b, _ = req("POST", "/api/like", {"id": eid}, token=tok)
        self.assertEqual(b["liked"], False)
        # admin: stats + delete_user; self-delete vetado
        st, _b, code = req("GET", "/api/stats")
        self.assertEqual((st, code), (403, "forbidden"))
        st, b, _ = req("POST", "/api/register",
                       {"username": "boss", "password": "pw1234"})
        adm = b["token"]
        st, b, _ = req("GET", "/api/stats", token=adm)
        self.assertEqual(st, 200)
        self.assertGreaterEqual(b["users"], 2)
        st, _b, code = req("POST", "/api/delete_user",
                           {"username": "boss"}, token=adm)
        self.assertEqual((st, code), (422, "invalid_user"))
        st, b, _ = req("POST", "/api/delete_user",
                       {"username": "alice"}, token=adm)
        self.assertEqual((st, b["deleted"]), (200, "alice"))
        # la entrada de alice se fue con ella
        st, b, _ = req("GET", "/api/feed")
        self.assertNotIn(eid, [e["id"] for e in b["entries"]])

    def test_mutant_unverifiable(self):
        st, b, _ = req("POST", "/api/register",
                       {"username": "mut_1", "password": "pw1234"})
        st, b, _ = req("POST", "/api/publish",
                       {"title": "m", "data": {"board": BOARD},
                        "rules": ["ice"], "moves": "r"},
                       token=b["token"])
        self.assertEqual((st, b["verified"]), (201, 0))

    def test_validation(self):
        st, b, _ = req("POST", "/api/register",
                       {"username": "val_1", "password": "pw1234"})
        tok = b["token"]
        bad = [({"data": {"board": 1}, "moves": "r"}, "board num"),
               ({"title": "x" * 200, "data": {"board": BOARD},
                 "moves": "r"}, "title largo"),
               ({"title": "t", "data": {"board": BOARD},
                 "rules": ["r"] * 9, "moves": "r"}, "9 reglas")]
        for body, what in bad:
            st, _b, code = req("POST", "/api/publish", body, token=tok)
            self.assertEqual((st, code), (422, "invalid_entry"), what)


if __name__ == "__main__":
    unittest.main(verbosity=2)
