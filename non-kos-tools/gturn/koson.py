import json as js

import numpy as np

_type_str = '$type'

_lex_type_code = 'kOS.Safe.Encapsulation.Lexicon'
_list_type_code = 'kOS.Safe.Encapsulation.ListValue'
_value_type_code = ''

_lex_entries = 'entries'
_list_items = 'items'


def load(fp, parse_float=None, parse_int=None, parse_constant=None, **kw):
    return js.load(fp,
                   object_hook=_load_raw,
                   parse_float=parse_float,
                   parse_int=parse_int,
                   parse_constant=parse_constant,
                   **kw)


def _load_raw(raw):
    if _is_lex(raw):
        return _load_lex(raw)
    elif _is_list(raw):
        return _load_list(raw)
    else:
        return raw


def _load_lex(lex_raw):
    assert _lex_entries in lex_raw
    entries = lex_raw[_lex_entries]
    assert len(entries) % 2 == 0
    res = dict()
    for key, value in zip(entries[0::2], entries[1::2]):
        res[key] = _load_raw(value)
    return res


def _load_list(list_raw):
    assert _list_items in list_raw
    items = list_raw[_list_items]
    res = list()
    for item in items:
        res.append(_load_raw(item))
    return res


def dump(data, fp, skipkeys=False, ensure_ascii=True, check_circular=True,
         allow_nan=True, cls=None, indent=None, separators=None, default=None,
         sort_keys=False, **kw):
    js.dump(_to_raw(data), fp,
            skipkeys=skipkeys,
            ensure_ascii=ensure_ascii,
            check_circular=check_circular,
            allow_nan=allow_nan,
            cls=cls,
            indent=indent,
            separators=separators,
            default=default,
            sort_keys=sort_keys,
            **kw)


def _to_raw(data):
    if isinstance(data, dict):
        return _to_lex(data)
    elif isinstance(data, (list, np.ndarray)):
        return _to_list(list(data))
    else:
        return data


def _to_lex(data):
    """
    :type data: dict
    """
    entries = []
    for key, value in data.items():
        assert isinstance(key, str)
        entries.append(key)
        entries.append(_to_raw(value))
    return {_lex_entries: entries,
            _type_str: _lex_type_code}


def _to_list(data):
    """
    :type data: list
    """
    return {_list_items: list(map(_to_raw, data)),
            _type_str: _list_type_code}


def _get_type(raw):
    """
    :type raw: dict
    """
    try:
        return raw.get(_type_str, _value_type_code)
    except AttributeError:
        return _value_type_code


def _is_lex(raw):
    return _get_type(raw) == _lex_type_code


def _is_list(raw):
    return _get_type(raw) == _list_type_code
