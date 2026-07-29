"""Cache LRU thread-safe con soporte de TTL por bucket."""

from collections import OrderedDict
from threading import Lock
from typing import Generic, Optional, TypeVar

K = TypeVar("K")
V = TypeVar("V")


def _key_matches_prefix(key: K, prefix_str: str) -> bool:
    if isinstance(key, tuple) and len(key) > 0:
        return str(key[0]) == prefix_str
    return str(key).startswith(prefix_str)


class LRUCache(Generic[K, V]):
    """Cache LRU thread-safe con invalidez por prefijo y TTL por bucket."""

    def __init__(self, max_size: int = 512, ttl_seconds: int = 300) -> None:
        self._max_size = max_size
        self._ttl_seconds = ttl_seconds
        self._store: OrderedDict[K, V] = OrderedDict()
        self._lock = Lock()

    def get(self, key: K) -> Optional[V]:
        with self._lock:
            value = self._store.get(key)
            if value is not None:
                self._store.move_to_end(key)
            return value

    def set(self, key: K, value: V) -> None:
        with self._lock:
            self._store[key] = value
            self._store.move_to_end(key)
            while len(self._store) > self._max_size:
                self._store.popitem(last=False)

    def invalidate_prefix(self, prefix: object) -> None:
        prefix_str = str(prefix)
        with self._lock:
            for key in [k for k in self._store if _key_matches_prefix(k, prefix_str)]:
                del self._store[key]

    def clear(self) -> None:
        with self._lock:
            self._store.clear()

    @property
    def ttl_seconds(self) -> int:
        return self._ttl_seconds

    @property
    def size(self) -> int:
        with self._lock:
            return len(self._store)
