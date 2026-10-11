"""RIFE v4.26 frame interpolation network (IFNet), for tools/idle_inbetweens.py.

The layer layout matches the published v4.26 weights, so a state dict loads
directly once its "module."/"flownet." prefixes are stripped. Weights are not
in Git; see docs/idle-inbetweens.md for where they come from.

Based on RIFE by hzwer (Practical-RIFE) and the vs-rife v4.26 port by HolyWu,
both under the MIT License:

  Copyright (c) 2021 hzwer
  Copyright (c) 2021 HolyWu

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F


def _conv(c_in, c_out):
    return nn.Sequential(nn.Conv2d(c_in, c_out, 3, 2, 1), nn.LeakyReLU(0.2, True))


class Head(nn.Module):
    """Per-frame features at full resolution, 4 channels."""

    def __init__(self):
        super().__init__()
        self.cnn0 = nn.Conv2d(3, 16, 3, 2, 1)
        self.cnn1 = nn.Conv2d(16, 16, 3, 1, 1)
        self.cnn2 = nn.Conv2d(16, 16, 3, 1, 1)
        self.cnn3 = nn.ConvTranspose2d(16, 4, 4, 2, 1)
        self.relu = nn.LeakyReLU(0.2, True)

    def forward(self, x):
        x = self.relu(self.cnn0(x))
        x = self.relu(self.cnn1(x))
        x = self.relu(self.cnn2(x))
        return self.cnn3(x)


class ResConv(nn.Module):
    def __init__(self, c):
        super().__init__()
        self.conv = nn.Conv2d(c, c, 3, 1, 1)
        self.beta = nn.Parameter(torch.ones((1, c, 1, 1)))
        self.relu = nn.LeakyReLU(0.2, True)

    def forward(self, x):
        return self.relu(self.conv(x) * self.beta + x)


class IFBlock(nn.Module):
    """Estimates flow (4 ch: to frame 0 and to frame 1), a blend mask and
    features at 1/scale of the input size."""

    def __init__(self, c_in, c):
        super().__init__()
        self.conv0 = nn.Sequential(_conv(c_in, c // 2), _conv(c // 2, c))
        self.convblock = nn.Sequential(*(ResConv(c) for _ in range(8)))
        self.lastconv = nn.Sequential(nn.ConvTranspose2d(c, 4 * 13, 4, 2, 1), nn.PixelShuffle(2))

    def forward(self, x, flow, scale):
        x = F.interpolate(x, scale_factor=1.0 / scale, mode="bilinear")
        if flow is not None:
            x = torch.cat((x, F.interpolate(flow, scale_factor=1.0 / scale, mode="bilinear") / scale), 1)
        out = F.interpolate(self.lastconv(self.convblock(self.conv0(x))), scale_factor=scale, mode="bilinear")
        return out[:, :4] * scale, out[:, 4:5], out[:, 5:]


class IFNet(nn.Module):
    """forward(img0, img1, t, scale) -> the frame at time t in [0, 1].

    Images are (N, 3, H, W) RGB in [0, 1]. H and W must be multiples of
    128 / scale: the coarsest block works at 1/(64 / scale).
    scale 1.0 estimates flow from 1/16 down to full size; 0.5 starts at 1/32,
    which follows large motions better and loses some fine detail."""

    def __init__(self):
        super().__init__()
        self.block0 = IFBlock(7 + 8, 192)
        self.block1 = IFBlock(8 + 4 + 8 + 8, 128)
        self.block2 = IFBlock(8 + 4 + 8 + 8, 96)
        self.block3 = IFBlock(8 + 4 + 8 + 8, 64)
        self.block4 = IFBlock(8 + 4 + 8 + 8, 32)
        self.encode = Head()
        self._grid_key = None

    def _warp(self, img, flow):
        n, _, h, w = img.shape
        if self._grid_key != (h, w, img.device):
            ys = torch.linspace(-1.0, 1.0, h, device=img.device)
            xs = torch.linspace(-1.0, 1.0, w, device=img.device)
            gy, gx = torch.meshgrid(ys, xs, indexing="ij")
            self._grid = torch.stack((gx, gy))[None]
            self._flow_div = ((w - 1.0) / 2.0, (h - 1.0) / 2.0)
            self._grid_key = (h, w, img.device)
        flow = torch.cat((flow[:, 0:1] / self._flow_div[0], flow[:, 1:2] / self._flow_div[1]), 1)
        grid = (self._grid + flow).permute(0, 2, 3, 1)
        return F.grid_sample(img, grid, mode="bilinear", padding_mode="border", align_corners=True)

    def forward(self, img0, img1, t=0.5, scale=1.0):
        img0, img1 = img0.clamp(0.0, 1.0), img1.clamp(0.0, 1.0)
        n, _, h, w = img0.shape
        time = torch.full((n, 1, h, w), float(t), device=img0.device, dtype=img0.dtype)
        f0, f1 = self.encode(img0), self.encode(img1)
        blocks = (self.block0, self.block1, self.block2, self.block3, self.block4)
        scales = [s / scale for s in (16, 8, 4, 2, 1)]
        flow, mask, feat = blocks[0](torch.cat((img0, img1, f0, f1, time), 1), None, scales[0])
        for block, s in zip(blocks[1:], scales[1:]):
            warped0, warped1 = self._warp(img0, flow[:, :2]), self._warp(img1, flow[:, 2:4])
            x = torch.cat((warped0, warped1, self._warp(f0, flow[:, :2]), self._warp(f1, flow[:, 2:4]), time, mask, feat), 1)
            delta, mask, feat = block(x, flow, s)
            flow = flow + delta
        m = torch.sigmoid(mask)
        return self._warp(img0, flow[:, :2]) * m + self._warp(img1, flow[:, 2:4]) * (1 - m)


def load(path, device):
    """Loads the original Practical-RIFE layout (block0.*) or the ComfyUI
    repackage (blocks.0.*)."""
    from safetensors.torch import load_file

    state = {}
    for key, value in load_file(str(path)).items():
        key = key.removeprefix("module.").removeprefix("flownet.")
        if key.startswith("blocks."):
            key = "block" + key.removeprefix("blocks.")[0] + key.removeprefix("blocks.")[1:]
        state[key] = value
    model = IFNet()
    model.load_state_dict(state)
    return model.float().to(device).eval()
