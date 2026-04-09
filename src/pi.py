import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.transforms.functional as TF
import cv2

import numpy as np

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class evalTransform():
    def __call__(self, img):
        img = img.unsqueeze(0)
        img = TF.resize(img, (480, 640))

        img = img.float() / 255.0
        img = TF.normalize(img, [0.5], [0.5])
        
        # add batch dimension
        return img.unsqueeze(0).to(device)

transform = evalTransform()


class ChannelAttention(nn.Module):
    def __init__(self, c, r=8):
        super().__init__()
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.mlp = nn.Sequential(
            nn.Conv2d(c, c // r, 1, bias=False),
            nn.ReLU(),
            nn.Conv2d(c // r, c, 1, bias = False)
        )

    def forward(self, x):
        a = self.pool(x)
        a = self.mlp(a)
        a = torch.sigmoid(a)
        return x * a

class SpatialAttention(nn.Module):
    def __init__(self, kernel_size=7):
        super().__init__()
        
        self.conv1 = nn.Conv2d(2, 1, kernel_size, padding=kernel_size//2, bias=False)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        avg_out = torch.mean(x, dim=1, keepdim=True)
        max_out, _ = torch.max(x, dim=1, keepdim=True)
        
        x_cat = torch.cat([avg_out, max_out], dim=1)
        out = self.conv1(x_cat)
        return x * self.sigmoid(out)

class CBAM_RES(nn.Module):
    def __init__(self, c, r=4):
        super().__init__()
        self.channel = ChannelAttention(c, r)
        self.spatial = SpatialAttention()
        self.out = nn.Conv2d(c, c, 1, 1)

    def forward(self, x):
        xc = self.channel(x)
        xc = self.spatial(xc)
        xc = self.out(xc)
        
        return xc + x * 0.1


## ------------- MODEL ---------------
c1, c2, c3, c4, c5, c6 = 8, 16, 32, 64, 128, 128
cf = 64

class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.pool = nn.MaxPool2d(2, 2)
        ## encoder
        self.e1 = nn.Sequential(
            nn.Conv2d(1, c1, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c1),
            nn.ReLU(),
            nn.Dropout2d(0.4)
        )
        self.e2 = nn.Sequential(
            nn.Conv2d(c1, c2, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c2),
            nn.ReLU(),
            nn.Dropout2d(0.4)
        )
        self.e3 = nn.Sequential(
            nn.Conv2d(c2, c3, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c3),
            nn.ReLU(),
            nn.Dropout2d(0.4)
        )
        self.e4 = nn.Sequential(
            nn.Conv2d(c3, c4, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c4),
            nn.ReLU(),
            nn.Dropout2d(0.4)
        )

        ## bottleneck
        self.bottleneck1 = nn.Sequential(
            nn.Conv2d(c4, c5, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c5),
            nn.ReLU(),
            nn.Conv2d(c5, c6, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c6),
            nn.ReLU(),
            nn.Conv2d(c6, c4, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c4),
            nn.ReLU()
        )
        ## ------- decoder --------
        ## up pool
        self.d_up4 = nn.Sequential(
            nn.Upsample(scale_factor=2, mode="bilinear", align_corners=True),
            nn.Conv2d(c4, c4, 3, 1, 1)
        )
        self.d_up3 = nn.Sequential(
            nn.Upsample(scale_factor=2, mode="bilinear", align_corners=True),
            nn.Conv2d(c3, c3, 3, 1, 1)
        )
        self.d_up2 = nn.Sequential(
            nn.Upsample(scale_factor=2, mode="bilinear", align_corners=True),
            nn.Conv2d(c2, c2, 3, 1, 1)
        )
        self.d_up1 = nn.Sequential(
            nn.Upsample(scale_factor=2, mode="bilinear", align_corners=True),
            nn.Conv2d(c1, c1, 3, 1, 1)
        )

        ##  up conv
        self.d_u4 = nn.Sequential(
            nn.Conv2d(c4*2, c3, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c3),
            nn.ReLU()
        )
        self.d_u3 = nn.Sequential(
            nn.Conv2d(c3*2, c2, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c2),
            nn.ReLU()
        )
        self.d_u2 = nn.Sequential(
            nn.Conv2d(c2*2, c1, 3, 1, 1, bias=False),
            nn.BatchNorm2d(c1),
            nn.ReLU()
        )
        self.d_u1 = nn.Sequential(
            nn.Conv2d(c1*2, cf, 3, 1, 1, bias=False),
            nn.BatchNorm2d(cf),
            nn.ReLU()
        )


        ## ----- skips ------
        self.s1 = CBAM_RES(c1)
        self.s2 = CBAM_RES(c2)
        self.s3 = CBAM_RES(c3)
        self.s4 = CBAM_RES(c4)

        ## ------- final -------
        self.final = nn.Conv2d(cf, 1, 1, 1)

    def forward(self, x):
        ## encoder
        ex1 = self.e1(x)
        ex2 = self.e2(self.pool(ex1))
        ex3 = self.e3(self.pool(ex2))
        ex4 = self.e4(self.pool(ex3))

        ## bottleneck
        bottleneck1 = self.bottleneck1(self.pool(ex4))

        ## decoder
        d_up4 = self.d_up4(bottleneck1)
        d_u4 = self.d_u4(torch.cat(
            [
                d_up4,
                self.s4(ex4)
            ], dim=1
        ))

        d_up3 = self.d_up3(d_u4)
        d_u3 = self.d_u3(torch.cat(
            [
                d_up3,
                self.s3(ex3)

            ], dim=1
        ))

        d_up2 = self.d_up2(d_u3)
        d_u2 = self.d_u2(torch.cat(
            [
                d_up2,
                self.s2(ex2)
            ], dim=1
        ))

        d_up1 = self.d_up1(d_u2)
        d_u1 = self.d_u1(torch.cat(
            [
                d_up1,
                self.s1(ex1)
            ], dim=1
        ))


        return self.final(d_u1)


model = Net().to(device)

print("Compiling Model...")
model = torch.compile(model)
print("Model Compiled!!")

model.load_state_dict(torch.load("src/road_extraction_trained_50_epochs.ckpt", weights_only=True))

model.eval()


WIDTH, HEIGHT = 640, 480
IMG_SIZE = WIDTH * HEIGHT 
TOTAL_EXPECTED = IMG_SIZE

cap = cv2.VideoCapture(0)

def get_current_frame():
    
    ret, frame = cap.read()
    while (not ret):
        ret, frame = cap.read()

    frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    frame = torch.from_numpy(frame)
    return transform(frame)


def calculate(mask):
    steer = 0
    speed = 0
    pooled = F.adaptive_avg_pool2d(mask, (3, 3))
    grid = pooled[0, 0]
    
    [[TL, TM, TR], 
     [CL, CM, CR], 
     [BL, BM, BR]] = grid

    err = ((CR - CL)*0.5 + (BR - BL)*1.5)
    steer = err.item()

    if CM <= 0.54:
        speed = 0.0
    else:
        speed = float((1.0 - abs(steer)) * (BM + CM) * 0.5)

    return max(min(speed, 1.0), -1.0), max(min(steer, 1.0), -1.0)


def set_speed_steer(speed, steer):
    pass

def loop():
    with torch.no_grad():
        while True:
            frame = get_current_frame()
            mask = model(frame)
            mask = torch.clamp(mask, 0.0, 1.0)
            mask = torch.sigmoid(mask)
            speed, steer = calculate(mask)
            set_speed_steer(speed, steer)

if __name__ == "__main__":
    try:
        loop()
    finally:
        cap.release()
        cv2.destroyAllWindows()
