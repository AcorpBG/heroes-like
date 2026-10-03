"""Remove hover-position ambiguity from the unsubmitted original death recipe."""
import json
import produce as p


def run():
    original = p.SOURCE_DIR / 'death_h3_v1'
    assert not (original / 'sampling_submission.json').exists()
    config = json.loads((original / 'config.json').read_bytes())
    old = 'Keep the single core near the same hover reference; the engine owns travel across the map.'
    new = 'Keep horizontal registration fixed while the single core physically descends from hover to the supplied ground-contact corpse; the engine owns travel across the map.'
    assert config['prompt'].count(old) == 1
    config['prompt'] = config['prompt'].replace(old, new)
    out = p.SOURCE_DIR / 'death_h3_v2'
    out.mkdir(exist_ok=True)
    if (out / 'sampling_submission.json').exists():
        assert json.loads((out / 'config.json').read_bytes()) == config
    else:
        p.write(out / 'config.json', config)
        p.prepare(out, config)
    p.verify(out, config)
    print('DEATH_GUIDES_PREPARED', out.name, flush=True)


if __name__ == '__main__':
    run()
