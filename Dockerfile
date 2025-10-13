### Builder stage: install .NET SDK and tools
FROM fedora:40 AS builder

RUN dnf -y install curl tar gzip && dnf clean all

ENV DOTNET_INSTALL_DIR=/usr/share/dotnet
ENV DOTNET_ROOT=${DOTNET_INSTALL_DIR}
ENV PATH="$PATH:${DOTNET_INSTALL_DIR}:/root/.dotnet/tools"

# Install .NET SDK 7.0
RUN curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
  && bash /tmp/dotnet-install.sh --channel 7.0 --install-dir ${DOTNET_INSTALL_DIR} \
  && rm -f /tmp/dotnet-install.sh

# Install dotnet-format as a global tool (installed to /root/.dotnet)
RUN ${DOTNET_INSTALL_DIR}/dotnet tool install -g dotnet-format || true


### Final stage: runtime image with Node.js, clang and the dotnet runtime/tools copied from builder
FROM fedora:40

# Install runtime packages: Node.js (from Fedora), clang for formatting, git
RUN dnf -y install \
  git \
  nodejs \
  npm \
  clang \
  clang-tools-extra \
  curl \
  && dnf clean all

# Copy dotnet runtime + tools from builder
COPY --from=builder /usr/share/dotnet /usr/share/dotnet
COPY --from=builder /root/.dotnet /root/.dotnet

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:/root/.dotnet/tools:/usr/share/dotnet"

WORKDIR /usr/src/unreal-linter

# Copy rules and scripts into the image
COPY unreal-asset-name.csv ./
COPY scripts/ ./scripts/
COPY .clang-format ./

RUN chmod +x scripts/run_checks.sh

ENTRYPOINT ["./scripts/run_checks.sh"]
